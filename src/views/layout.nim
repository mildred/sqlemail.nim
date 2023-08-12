import templates
import prologue

import ./common

proc layout*(ctx: Context, main: string, title: string = ""): string = tmpli html"""
  <html>
    <head>
      <title>$(h(title))</title>
      <style>
        @import url(/assets/styles.css)
      </style>
      <!--
        JSPM Generator Import Map
        Edit URL: https://generator.jspm.io
      -->
    </head>
    <body>
      <main>
        $main
      </main>
    </body>
  </html>
  """



