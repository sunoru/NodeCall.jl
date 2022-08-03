using NodeCall

NodeCall.initialize()

cd(@__DIR__)
run(npm`install`)

const puppeteer = require("puppeteer")
const console = node"console"

const browser = @await puppeteer.launch()
page = @await browser.newPage()
@await page.goto("https://example.com")
@await page.screenshot((path="example.png",))

pages = @await browser.pages()
@show [fetch(page.title()) for page in pages]

@await browser.close()
