import { Editor } from "@tiptap/core";
import StarterKit from '@tiptap/starter-kit'
import Highlight from '@tiptap/extension-highlight'
import Typography from '@tiptap/extension-typography'
import BubbleMenu from '@tiptap/extension-bubble-menu'
import FloatingMenu from '@tiptap/extension-floating-menu'

const editorElement = document.querySelector('div[name="editor"]')
const bubbleMenuElement = document.querySelector('template[name="editor-bubble-menu"]').content.firstElementChild
const floatingMenuElement = document.querySelector('template[name="editor-floating-menu"]').content.firstElementChild

const bBold   = bubbleMenuElement.querySelector('[name="bold"]')
const bItalic = bubbleMenuElement.querySelector('[name="italic"]')
const bStrike = bubbleMenuElement.querySelector('[name="strike"]')
const bUnder  = bubbleMenuElement.querySelector('[name="underline"]')
const bH1   = floatingMenuElement.querySelector('[name="h1"]')
const bH2   = floatingMenuElement.querySelector('[name="h2"]')
const bUl   = floatingMenuElement.querySelector('[name="ul"]')
const bPar  = floatingMenuElement.querySelector('[name="p"]')
const bBq   = floatingMenuElement.querySelector('[name="bq"]')

const unsavedBanner = document.querySelector('.editor-unsaved')
const saveButton = unsavedBanner.querySelector('button')

const editor = new Editor({
  element: editorElement,
  content: (() => {
    const html = editorElement.innerHTML
    editorElement.innerHTML = ""
    return html
  })(),
  extensions: [
    StarterKit,
    Typography,
    // Disable bubble menu because disputatio is not able yet to handle inline
    // styling
    //BubbleMenu.configure({
    //  element: bubbleMenuElement,
    //}),
    FloatingMenu.configure({
      element: floatingMenuElement,
    }),
  ],
  onTransaction: () => {
    bBold.classList.toggle('is-active',   editor.isActive('bold'))
    bItalic.classList.toggle('is-active', editor.isActive('italic'))
    bStrike.classList.toggle('is-active', editor.isActive('strike'))
    bUnder.classList.toggle('is-active',  editor.isActive('underline'))
    bH1.classList.toggle('is-active',     editor.isActive('heading', { level: 1 }))
    bH2.classList.toggle('is-active',     editor.isActive('heading', { level: 2 }))
    bUl.classList.toggle('is-active',     editor.isActive('bulletList'))
    bPar.classList.toggle('is-active',    editor.isActive('paragraph'))
    bBq.classList.toggle('is-active',     editor.isActive('blockquote'))
  },
  onUpdate({ editor }) {
    unsavedBanner.style.display = 'block';
  },
})

bBold.onclick   = () => { editor.chain().focus().toggleBold().run() }
bItalic.onclick = () => { editor.chain().focus().toggleItalic().run() }
bStrike.onclick = () => { editor.chain().focus().toggleStrike().run() }
bUnder.onclick  = () => { editor.chain().focus().toggleUnderline().run() }
bH1.onclick     = () => { editor.chain().focus().toggleHeading({ level: 1 }).run() }
bH2.onclick     = () => { editor.chain().focus().toggleHeading({ level: 2 }).run() }
bUl.onclick     = () => { editor.chain().focus().toggleBulletList().run() }
bPar.onclick    = () => { editor.chain().focus().setParagraph().run() }
bBq.onclick     = () => { editor.chain().focus().toggleBlockquote().run() }

saveButton.onclick = async (e) => {
  e.preventDefault();
  const html = editor.getHTML();
  const form = new FormData()
  const spinner = e.target.parentElement.querySelector('.spinner')
  spinner.classList.toggle('invisible', false)
  try {
    form.append("html", html)
    form.append("parent_patch", editorElement.dataset.patchId)
    const resp = await fetch('./', {method: 'POST', body: form})
    if (resp.status < 400) {
      unsavedBanner.style.display = 'none';
    } else {
      console.log(resp)
      let body = await resp.text()
      console.log(body)
      alert(resp.statusText)
    }
  } finally {
    spinner.classList.toggle('invisible', true)
  }
}
