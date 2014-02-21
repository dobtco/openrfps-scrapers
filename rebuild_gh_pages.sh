#! /bin/sh

git checkout gh-pages
<<<<<<< HEAD
git merge master
=======
git merge master -m "Merge master"
>>>>>>> master
docco scrapers/states/ga/rfps.coffee
git commit -am "Update docs"
git push origin gh-pages
git checkout master