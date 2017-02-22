--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Text.Pandoc.Options


pandocReaderOptions :: ReaderOptions
pandocReaderOptions = defaultHakyllReaderOptions 
pandocWriterOptions :: WriterOptions
pandocWriterOptions = defaultHakyllWriterOptions 
                      { writerHTMLMathMethod = MathJax ""  
                        , writerTableOfContents = True 
                        , writerHtmlQTags = True 
                        , writerStandalone = True 
                        , writerTemplate = unlines[ "$toc$", "$body$" ] }

--------------------------------------------------------------------------------

main :: IO ()
main = hakyll $ do
    match ("images/*" .||. "charts/*") $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match "mortchartdoc.md" $ do
        route   $ setExtension "html"
        compile $ bibtexCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            let indexCtx =
                    constField "title" "Huvudsida"                `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler
    match "*.bib" $ compile biblioCompiler
    match "*.csl" $ compile cslCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

bibtexCompiler :: Compiler (Item String)
bibtexCompiler = do 
    csl <- load "default.csl" 
    bib <- load "mortchartdoc_biber.bib"
    getResourceBody 
      >>= readPandocBiblio pandocReaderOptions csl bib
      >>= return . writePandocWith pandocWriterOptions
