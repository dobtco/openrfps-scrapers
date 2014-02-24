#! /bin/sh

git checkout gh-pages
git merge master -m "Merge master"
docco scrapers/ga/rfps.coffee
git commit -am "Update docs"
git push origin gh-pages
git checkout master