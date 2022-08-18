import templates
import qr

import ./common

func login_totp*(email: string): string = tmpli html"""
  <article>
    <form method="POST" action="?">
      <input type="hidden" name="email" value="$(h(email))" />
      <input type="input" name="otp" />
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


