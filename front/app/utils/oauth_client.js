import getPkce from 'oauth-pkce';
import { get } from './store.js'

export class OAuthClient {

  constructor(domain, store) {
    this.domain = domain
    this.store = store
    this.get_from_store()
  }

  get_from_store() {
    if (!this.store) return

    const data = get(this.store)
    // console.log("[oauth] get tokens from store", data)

    this.access_token = data.oauth_access_token
    this.token_type = data.oauth_token_type
    this.access_token_limit = new Date(data.oauth_access_token_limit)
    this.refresh_token = data.oauth_refresh_token
  }

  async handle_unauthorized(res) {
    if (this.access_token_limit < new Date()) {
      console.log("[oauth] Received unauthorized, refresh token", this)
      await this.oauth_get_token({
        'grant_type':    'refresh_token',
        'refresh_token': this.refresh_token
      })
    } else {
      console.log("[oauth] Received unauthorized, issue new login", this)
      return await this.login()
    }
  }

  async handle_unauthorized_get_token(res) {
    console.log("[oauth] Received unauthorized while requesting a new token, issue new login", this)
    return await this.login()
  }

  get oauth_redirect_url() { return `${location.origin}/app/utils/oauth_response.html` }
  get oauth_client_id()    { return '0' }

  get_pkce_async(size) {
    return new Promise((resolve, reject) => getPkce(size, (error, res) => {
      if (error) reject(error)
      else resolve(res)
    }))
  }

  async oauth_auth(auth_url, params) {
    const url = auth_url
      + `?client_id=${encodeURIComponent(params.client_id)}`
      + `&redirect_uri=${encodeURIComponent(params.redirect_uri)}`
      + '&response_type=code'
      + `&state=${encodeURIComponent(params.state)}`
      + `&scope=${encodeURIComponent((params.scopes || []).join(' '))}`
      + `&code_challenge=${encodeURIComponent(params.code_challenge)}`
      + `&code_challenge_method=${encodeURIComponent(params.code_challenge_method || 'S256')}`

    return await new Promise((accept) => {
      window.addEventListener('message', onMessage)

      window.open(url, '_blank')

      function onMessage(e){
        if (!typeof(e.data) == 'object') return;
        if (!e.data["oauth-response"]) return

        const res_params = Object.fromEntries(e.data["oauth-response"])
        if(res_params.state == params.state) {
          window.removeEventListener('message', onMessage)
          accept(res_params)
        } else {
          console.error("Received mismatching state from %o\nevent: %o", res_params, e)
        }
      }
    })
  }

  async request_oauth_metadata() {
    const res = await fetch(new URL('/.well-known/oauth-authorization-server', this.domain).toString())
    const body = await res.json()
    return body
  }

  async login() {
    this.oauth_metadata ||= await this.request_oauth_metadata()

    const state_size = 32
    const challenge_size = 48
    const state = Array.from(crypto.getRandomValues(new Uint8Array(state_size)), i => i.toString(16).padStart(2, "0")).join(""); 
    const { verifier, challenge } = await this.get_pkce_async(challenge_size)

    const params = await this.oauth_auth(this.oauth_metadata.authorization_endpoint, {
      client_id: this.oauth_client_id,
      redirect_uri: this.oauth_redirect_url,
      response_type: 'code',
      state: state,
      scope: [],
      code_challenge: challenge,
      code_challenge_method: 'S256',
    })

    await this.oauth_get_token({
      'grant_type':    'authorization_code',
      'code':          params.code,
      'code_verifier': verifier,
      'redirect_uri':  this.oauth_redirect_url
    })
  }

  async oauth_get_token(params) {
    while (true) {
      this.oauth_metadata ||= await this.request_oauth_metadata()
      const now = new Date()

      const resp = await fetch(this.oauth_metadata.token_endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          'client_id': this.oauth_client_id,
          ...params
        })
      })

      if (resp.status == 401) {
        await this.handle_unauthorized_get_token(resp)
        continue
      }

      if (resp.status != 200) {
        console.error('[oauth] Failed to get tokens', await resp.json())
        throw new Error('[oauth] Failed to get tokens');
        continue
      }

      const tokens = await resp.json()
      const limit = now.getTime() + tokens.expires_in * 1000 - 60000
      this.access_token = tokens.access_token
      this.token_type = tokens.token_type
      this.access_token_limit = new Date(limit)
      this.refresh_token = tokens.refresh_token

      console.log('[oauth] Got new tokens', tokens, this)

      if (this.store) {
        this.store.update(data => ({
          ...data,
          oauth_access_token: tokens.access_token,
          oauth_token_type: tokens.token_type,
          oauth_access_token_limit: limit,
          oauth_refresh_token: tokens.refresh_token
        }))
        console.log('[oauth] Got new tokens in store', get(this.store))
      }
      return
    }
  }

  async get_authorization_header() {
    this.get_from_store()
    if (! this.access_token) {
      await this.login()
    }
    try {
      if (this.access_token_limit < new Date()) {
        console.log("[oauth] Refresh token")
        await this.oauth_get_token({
          'grant_type':    'refresh_token',
          'refresh_token': this.refresh_token
        })
      }
    } catch (e) {
      console.error(e)
      await this.login()
    }
    return `${this.token_type} ${this.access_token}`
  }

}

