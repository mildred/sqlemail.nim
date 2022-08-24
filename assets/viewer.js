//let paragraphs = document.querySelectorAll('[id^="paragraph-"]')

const viewerElement = document.querySelector('article.viewer')
const paragraphMenuElement = document.querySelector('template[name="viewer-paragraph-menu"]').content.firstElementChild

viewerElement.addEventListener('mouseover', onMouseOver)
viewerElement.addEventListener('mouseout', onMouseOut)

function onMouseOver(e) {
  const par = e.target.closest('[id^="paragraph-"]')
  if (e.target == paragraphMenuElement) {
    if (paragraphMenuElement.timeout) clearTimeout(paragraphMenuElement.timeout)
  } else if (par) {
    if (paragraphMenuElement.timeout) clearTimeout(paragraphMenuElement.timeout)
    par.appendChild(paragraphMenuElement)
    par.style.position = 'relative'
    paragraphMenuElement.style.position = 'absolute'
    paragraphMenuElement.style.left = '1rem'
    paragraphMenuElement.style.borderTopLeftRadius = '0'
    paragraphMenuElement.style.borderTopRightRadius = '0'
  }
}

function onMouseOut(e) {
  const par = e.target.closest('[id^="paragraph-"]')
  if ((par && par == paragraphMenuElement.parentElement) || e.target == paragraphMenuElement) {
    if (paragraphMenuElement.timeout) clearTimeout(paragraphMenuElement.timeout)
    paragraphMenuElement.timeout = setTimeout(() => {
      paragraphMenuElement.timeout = undefined
      paragraphMenuElement.parentElement.style.position = undefined
      paragraphMenuElement.remove()
    }, 1000)
  }
}

