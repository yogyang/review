### About Git

[TOC]

#### Move some files from repo-a to a new repo-b 

http://gbayer.com/development/moving-files-from-one-git-repository-to-another-preserving-history/

##### Goal

- Move directory 1 from Git repository A to Git repository B.

##### Constraints

- Git repository A contains other directories that we don’t want to move.
- We’d like to perserve the Git commit history for the directory we are moving.



##### Get files ready for the move:

Make a copy of repository A so you can mess with it without worrying about mistakes too much.  It’s also a good idea to delete the link to the original repository to avoid accidentally making any remote changes (line 3).  Line 4 is the critical step here.  It goes through your history and files, removing anything that is not in directory 1.  The result is the contents of directory 1 spewed out into to the base of repository A.  You probably want to import these files into repository B within a directory, so move them into one now (lines 5/6). Commit your changes and we’re ready to merge these files into the new repository.

```
git clone <git repository A url>
cd <git repository A directory>
git remote rm origin
git filter-branch --subdirectory-filter <directory 1> -- --all
mkdir <directory 1>
mv * <directory 1>
git add .
git commit

```

##### Merge files into new repository:

Make a copy of repository B if you don’t have one already.  On line 3, you’ll create a remote connection to repository A as a branch in repository B.  Then simply pull from this branch (containing only the directory you want to move) into repository B.  The pull copies both files and history.  Note: You can use a merge instead of a pull, but pull worked better for me. Finally, you probably want to clean up a bit by removing the remote connection to repository A. Commit and you’re all set.

```
git clone <git repository B url>
cd <git repository B directory>
git remote add repo-A-branch <git repository A directory>
git pull repo-A-branch master --allow-unrelated-histories
git remote rm repo-A-branch

```

