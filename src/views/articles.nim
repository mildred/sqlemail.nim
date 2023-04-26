import templates

import ./common

func article_new*(): string = tmpli html"""
  <article>
    <form method="POST" action="./">
      <input type="text" name="name" />
      <input type="submit" value="Create"/>
    </form>
  </article>
"""

func article_index*(): string = tmpli html"""
  <article>
    <p>List of articles from this user:</p>
    <ul>
      <li>WIP</li>
    </ul>
  </article>
"""

func article_view*(patch_id, markup: string): string = tmpli html"""
  <nav>
    <ul>
      <li><a href="./edit">Edit</a></li>
    </ul>
  </nav>
  <script>
    // https://github.com/atomiks/tippyjs/issues/990
    window.process = { env: { NODE_ENV: 'production' }}
  </script>
  <template name="viewer-paragraph-menu">
    <div class="viewer viewer-menu hmenu">
      <button name="comment"><svg fill="currentColor"><use xlink:href="/assets/bootstrap-icons.svg#chat-left-text"/></svg></button>
    </div>
  </template>
  <script type="module" src="/assets/viewer.js"></script>
  <style>
    @import url(/assets/viewer.css)
  </style>
  <article data-patch-id="$(h(patch_id))" class="viewer">$markup</article>
"""

func article_editor*(patch_id, markup: string, fullpage: bool = true, url: string = "./", save_btn: string = "Save"): string = tmpli html"""
  <div class="editor-container $(if fullpage: "fullpage" else: "embedded")">
    <script>
      // https://github.com/atomiks/tippyjs/issues/990
      window.process = { env: { NODE_ENV: 'production' }}
    </script>
    <script type="module" src="/assets/editor.js"></script>
    <template name="editor-bubble-menu">
      <div class="editor editor-menu hmenu">
        <button name="bold">B</button>
        <button name="italic">I</button>
        <button name="underline">U</button>
        <button name="strike">S</button>
      </div>
    </template>
    <template name="editor-floating-menu">
      <div class="editor editor-menu hmenu">
        <button name="h1">H1</button>
        <button name="h2">H2</button>
        <button name="ul"><svg fill="currentColor"><use xlink:href="/assets/bootstrap-icons.svg#list-ul"/></svg></button>
        <button name="p"><svg fill="currentColor"><use xlink:href="/assets/bootstrap-icons.svg#text-paragraph"/></svg></button>
        <button name="bq"><svg fill="currentColor"><use xlink:href="/assets/bootstrap-icons.svg#blockquote-left"/></svg></button>
      </div>
    </template>
    <style>
      @import url(/assets/editor.css)
    </style>
    $if fullpage {
      <nav>
        <ul>
          <li><a href="./">View</a></li>
        </ul>
      </nav>
    }
    <article class="editor">
      <div class="html-editor" name="editor" data-patch-id="$(h(patch_id))" data-url="$(h(url))">$markup</div>
    </article>
    <p class="editor editor-unsaved" style="display: none">
      <span class="unsaved-message">You have unsaved changes</span>
      <button><span class="spinner invisible"></span>$(h(save_btn))</button>
    </p>
  </div>
"""
