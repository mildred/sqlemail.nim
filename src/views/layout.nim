import templates
import prologue

import ./common

func layout*(ctx: Context, main, title: string): string = tmpli html"""
  <html>
    <head>
      <title>$(h(title)) - Accounts</title>
      <link rel="stylesheet" href="https://unpkg.com/mvp.css">
      <style>
        form[role=none] {
          display: inline;
          border: none;
          padding: 0;
          margin: 0;
        }
        [role=link] {
          display: inline-block;
          padding: 0;
          margin: 0;
          border: none;
          cursor: pointer;
          color: var(--color-secondary);
          font-weight: bold;
        }
        [role=link]:hover {
          filter: brightness(var(--hover-brightness));
          text-decoration: underline;
        }
      </style>
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
                <a href="/login/$(h(ctx.session.getOrDefault("email", "")))">$(h(ctx.session.getOrDefault("email", "")))</a>
                <ul>
                  <li><a href="/logout">Logout</a></li>
                </ul>
              </li>
            }
          </ul>
        </nav>
        <h1>$title</h1>
      </header>
      <main>
        $main
      </main>
    </body>
  </html>
  """



