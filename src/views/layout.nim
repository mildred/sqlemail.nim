import templates
import prologue

import ./common
import ../context

func layout*(ctx: Context, main: string, title: string = ""): string = tmpli html"""
  <html>
    <head>
      <title>$(h(title)) - Accounts</title>
      <link rel="stylesheet" href="https://unpkg.com/mvp.css">
      <style>
        @import url(/assets/styles.css)
      </style>
      <!-- Can be enabled in firefox with the dom.importMaps.enabled pref in about:config. -->
      <!--
        JSPM Generator Import Map
        Edit URL: https://generator.jspm.io/#bc5BDsIgEAVQFsabuAQLpo2u2kt4ANARJuJA6DSxt9eVYmTxV//l5+82QmzHMzFyhKuYGDPbvL+kApNRneqkA7ZKH82ngycDzZhIusW5CPIBtNR40A17i8kykv/T/dDQAX2I73AtD31D8pqTLzaHtabme3dmWxiKvOPPmD7pF4zmQAr8AA
      -->
      <script type="importmap">
      {
        "imports": {
          "@tiptap/core": "https://ga.jspm.io/npm:@tiptap/core@2.0.0-beta.182/dist/tiptap-core.esm.js",
          "@tiptap/extension-bubble-menu": "https://ga.jspm.io/npm:@tiptap/extension-bubble-menu@2.0.0-beta.61/dist/tiptap-extension-bubble-menu.esm.js",
          "@tiptap/extension-floating-menu": "https://ga.jspm.io/npm:@tiptap/extension-floating-menu@2.0.0-beta.56/dist/tiptap-extension-floating-menu.esm.js",
          "@tiptap/extension-highlight": "https://ga.jspm.io/npm:@tiptap/extension-highlight@2.0.0-beta.35/dist/tiptap-extension-highlight.esm.js",
          "@tiptap/extension-typography": "https://ga.jspm.io/npm:@tiptap/extension-typography@2.0.0-beta.22/dist/tiptap-extension-typography.esm.js",
          "@tiptap/starter-kit": "https://ga.jspm.io/npm:@tiptap/starter-kit@2.0.0-beta.191/dist/tiptap-starter-kit.esm.js"
        },
        "scopes": {
          "https://ga.jspm.io/": {
            "@popperjs/core": "https://ga.jspm.io/npm:@popperjs/core@2.11.6/lib/index.js",
            "@tiptap/extension-blockquote": "https://ga.jspm.io/npm:@tiptap/extension-blockquote@2.0.0-beta.29/dist/tiptap-extension-blockquote.esm.js",
            "@tiptap/extension-bold": "https://ga.jspm.io/npm:@tiptap/extension-bold@2.0.0-beta.28/dist/tiptap-extension-bold.esm.js",
            "@tiptap/extension-bullet-list": "https://ga.jspm.io/npm:@tiptap/extension-bullet-list@2.0.0-beta.29/dist/tiptap-extension-bullet-list.esm.js",
            "@tiptap/extension-code": "https://ga.jspm.io/npm:@tiptap/extension-code@2.0.0-beta.28/dist/tiptap-extension-code.esm.js",
            "@tiptap/extension-code-block": "https://ga.jspm.io/npm:@tiptap/extension-code-block@2.0.0-beta.42/dist/tiptap-extension-code-block.esm.js",
            "@tiptap/extension-document": "https://ga.jspm.io/npm:@tiptap/extension-document@2.0.0-beta.17/dist/tiptap-extension-document.esm.js",
            "@tiptap/extension-dropcursor": "https://ga.jspm.io/npm:@tiptap/extension-dropcursor@2.0.0-beta.29/dist/tiptap-extension-dropcursor.esm.js",
            "@tiptap/extension-gapcursor": "https://ga.jspm.io/npm:@tiptap/extension-gapcursor@2.0.0-beta.39/dist/tiptap-extension-gapcursor.esm.js",
            "@tiptap/extension-hard-break": "https://ga.jspm.io/npm:@tiptap/extension-hard-break@2.0.0-beta.33/dist/tiptap-extension-hard-break.esm.js",
            "@tiptap/extension-heading": "https://ga.jspm.io/npm:@tiptap/extension-heading@2.0.0-beta.29/dist/tiptap-extension-heading.esm.js",
            "@tiptap/extension-history": "https://ga.jspm.io/npm:@tiptap/extension-history@2.0.0-beta.26/dist/tiptap-extension-history.esm.js",
            "@tiptap/extension-horizontal-rule": "https://ga.jspm.io/npm:@tiptap/extension-horizontal-rule@2.0.0-beta.36/dist/tiptap-extension-horizontal-rule.esm.js",
            "@tiptap/extension-italic": "https://ga.jspm.io/npm:@tiptap/extension-italic@2.0.0-beta.28/dist/tiptap-extension-italic.esm.js",
            "@tiptap/extension-list-item": "https://ga.jspm.io/npm:@tiptap/extension-list-item@2.0.0-beta.23/dist/tiptap-extension-list-item.esm.js",
            "@tiptap/extension-ordered-list": "https://ga.jspm.io/npm:@tiptap/extension-ordered-list@2.0.0-beta.30/dist/tiptap-extension-ordered-list.esm.js",
            "@tiptap/extension-paragraph": "https://ga.jspm.io/npm:@tiptap/extension-paragraph@2.0.0-beta.26/dist/tiptap-extension-paragraph.esm.js",
            "@tiptap/extension-strike": "https://ga.jspm.io/npm:@tiptap/extension-strike@2.0.0-beta.29/dist/tiptap-extension-strike.esm.js",
            "@tiptap/extension-text": "https://ga.jspm.io/npm:@tiptap/extension-text@2.0.0-beta.17/dist/tiptap-extension-text.esm.js",
            "orderedmap": "https://ga.jspm.io/npm:orderedmap@2.0.0/dist/index.js",
            "prosemirror-commands": "https://ga.jspm.io/npm:prosemirror-commands@1.3.0/dist/index.js",
            "prosemirror-dropcursor": "https://ga.jspm.io/npm:prosemirror-dropcursor@1.5.0/dist/index.js",
            "prosemirror-gapcursor": "https://ga.jspm.io/npm:prosemirror-gapcursor@1.3.0/dist/index.js",
            "prosemirror-history": "https://ga.jspm.io/npm:prosemirror-history@1.3.0/dist/index.js",
            "prosemirror-keymap": "https://ga.jspm.io/npm:prosemirror-keymap@1.2.0/dist/index.js",
            "prosemirror-model": "https://ga.jspm.io/npm:prosemirror-model@1.18.1/dist/index.js",
            "prosemirror-schema-list": "https://ga.jspm.io/npm:prosemirror-schema-list@1.2.0/dist/index.js",
            "prosemirror-state": "https://ga.jspm.io/npm:prosemirror-state@1.4.1/dist/index.js",
            "prosemirror-transform": "https://ga.jspm.io/npm:prosemirror-transform@1.6.0/dist/index.js",
            "prosemirror-view": "https://ga.jspm.io/npm:prosemirror-view@1.26.2/dist/index.js",
            "rope-sequence": "https://ga.jspm.io/npm:rope-sequence@1.3.3/dist/index.es.js",
            "tippy.js": "https://ga.jspm.io/npm:tippy.js@6.3.7/dist/tippy.esm.js",
            "w3c-keyname": "https://ga.jspm.io/npm:w3c-keyname@2.2.6/index.es.js"
          }
        }
      }
      </script>
    </head>
    <body>
      <header>
        <nav>
          <a href="/">Home</a>
          <ul>
            $if ctx.session.getOrDefault("email", "") == "" {
              <li><a href="/login">Login</a></li>
            }
            $else {
              <li>
                <a href="/~$(hash_email(ctx.session.getOrDefault("email", "")))/">$(h(ctx.session.getOrDefault("email", "")))</a>
                <ul>
                  <li><a href="/login/$(h(ctx.session.getOrDefault("email", "")))">Settings</a></li>
                  <li><a href="/logout">Logout</a></li>
                </ul>
              </li>
            }
          </ul>
        </nav>
        $if title != "" {
          <h1>$title</h1>
        }
      </header>
      <main>
        $main
      </main>
    </body>
  </html>
  """



