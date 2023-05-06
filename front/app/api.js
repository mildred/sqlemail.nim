import { OAuthClient } from './utils/oauth_client.js'

export class API {
  constructor(domain, store) {
    this.domain = domain || window.location
    this.auth = new OAuthClient(domain, store)
  }

  get api_url() {
    return new URL('/.well-known/disputatio/', this.domain).toString()
  }

  async request_session() {
    if (this.session) return this.session

    while(true) {
      const res = await fetch(this.api_url, {
        headers: { 'Authorization': await this.auth.get_authorization_header() }
      })
      if (res.status == 401) {
        await this.auth.handle_unauthorized(res)
        continue
      }
      const body = await res.json()
      this.session = body
      console.log("[jmap] session = %o", body)
      return body
    }
  }

  async sql(sql_statement) {
    while(true) {
      const res = await fetch(this.api_url, {
        method: 'POST',
        headers: { 'Authorization': await this.auth.get_authorization_header() },
        body: JSON.stringify({
          sql: sql_statement
        })
      })
      if (res.status == 401) {
        await this.auth.handle_unauthorized(res)
        continue
      }
      const body = await res.json()
      this.session = body
      console.log("[jmap] post response = %o", body)
      return body
    }
  }
}

