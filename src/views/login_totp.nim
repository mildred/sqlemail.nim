import templates
import qr

import ./common

func login_totp*(email, otp: string, redirect_url: string = ""): string = tmpli html"""
  <article>
    <form method="POST" action="/login">
      <input type="hidden" name="redirect_url" value="$(h(redirect_url))" />
      <input type="hidden" name="email" value="$(h(email))" />
      <input type="input" name="otp" value="$(h(otp))" />
      <input type="submit" value="Log-In"/>
    </form>
  </article>
  """

func login_totp_ok*(url: string): string = tmpli html"""
  <header>
    <a href="$(h(url))">
      $( qrSvg(url) )
    </a>
  </header>
  """


