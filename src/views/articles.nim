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
  <article data-patch-id="$(h(patch_id))">$markup</article>
"""

func article_editor*(patch_id, markup: string): string = tmpli html"""
  <script>
    // https://github.com/atomiks/tippyjs/issues/990
    window.process = { env: { NODE_ENV: 'production' }}
  </script>
  <script type="module" src="/assets/editor.js"></script>
  <template name="editor-bubble-menu">
    <div class="editor editor-menu">
      <button name="bold">B</button>
      <button name="italic">I</button>
      <button name="underline">U</button>
      <button name="strike">S</button>
    </div>
  </template>
  <template name="editor-floating-menu">
    <div class="editor editor-menu">
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
  <article>
    <div class="html-editor" name="editor" data-patch-id="$(h(patch_id))">$markup</div>
  </article>
  <p class="editor editor-unsaved" style="display: none">
    You have unsaved changes
    <button><span class="spinner invisible"></span>Save</button>
  </p>
"""
