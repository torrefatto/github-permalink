vim9script

var repo = $GITHUB_PERMALINK_TEST_REPO
var commit = systemlist($'git -C {shellescape(repo)} rev-parse HEAD')[0]
var failures: list<string> = []


def Check(actual: string, expected: string, label: string)
    if actual != expected
        failures->add($'{label}: expected {expected}, got {actual}')
    endif
enddef


def CheckFailure(command: string, expected: string, label: string)
    try
        execute command
        failures->add($'{label}: command unexpectedly succeeded')
    catch
        Check(v:exception, expected, label)
    endtry
enddef


execute $'edit {fnameescape(repo .. "/dir/a b.txt")}'
cursor(1, 1)
execute 'GitHubPermalink'
Check(getreg('"'), $'https://github.com/example/project/blob/{commit}/dir/a%20b.txt#L1', 'current line')

normal! 2GV4G
execute "normal \\gy"
Check(getreg('"'), $'https://github.com/example/project/blob/{commit}/dir/a%20b.txt#L2-L4', 'visual selection')

execute $'edit {fnameescape(repo .. "/dir/café.txt")}'
cursor(2, 1)
execute 'GitHubPermalink'
Check(getreg('"'), $'https://github.com/example/project/blob/{commit}/dir/caf%C3%A9.txt#L2', 'UTF-8 path')

setline(1, 'changed in buffer')
CheckFailure('GitHubPermalink', 'github_permalink: save the current buffer before creating a permalink', 'modified buffer')
setlocal nomodified

execute $'edit {fnameescape(repo .. "/dirty.txt")}'
CheckFailure('GitHubPermalink', 'github_permalink: the current file differs from HEAD', 'modified working-tree file')

execute $'edit {fnameescape(repo .. "/untracked.txt")}'
CheckFailure('GitHubPermalink', $'github_permalink: fatal: path ''untracked.txt'' exists on disk, but not in ''{commit}''', 'untracked file')

execute $'edit {fnameescape(repo .. "/../outside.txt")}'
CheckFailure('GitHubPermalink', 'github_permalink: fatal: not a git repository (or any of the parent directories): .git', 'file outside Git')

execute $'edit {fnameescape(repo .. "/dir/a b.txt")}'
system($'git -C {shellescape(repo)} remote set-url origin git@gitlab.com:example/project.git')
CheckFailure('GitHubPermalink', 'github_permalink: no remote hosted on github.com was found', 'non-GitHub remote')

if !failures->empty()
    writefile(failures, repo .. '/failures')
    cquit
endif

quitall
