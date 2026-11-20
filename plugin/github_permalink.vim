vim9script

if exists('g:loaded_github_permalink')
    finish
endif
g:loaded_github_permalink = true


def Git(cwd: string, args: list<string>): list<string>
    var command = (['git', '-C', cwd] + args)->mapnew((_, arg) => shellescape(arg))->join(' ')
    var output = systemlist(command)
    var status = v:shell_error
    if status != 0
        var detail = output->join(' ')->trim()
        throw detail->empty()
            ? $'github_permalink: git {args->join(" ")} failed'
            : $'github_permalink: {detail}'
    endif
    return output
enddef


def GitMaybe(cwd: string, args: list<string>): list<string>
    var command = (['git', '-C', cwd] + args)->mapnew((_, arg) => shellescape(arg))->join(' ')
    var output = systemlist(command)
    return v:shell_error == 0 ? output : []
enddef


def EnsureFileMatchesHead(root: string, relative_file: string)
    var args = ['diff', '--quiet', 'HEAD', '--', relative_file]
    var command = (['git', '-C', root] + args)->mapnew((_, arg) => shellescape(arg))->join(' ')
    var output = systemlist(command)
    var status = v:shell_error
    if status == 1
        throw 'github_permalink: the current file differs from HEAD'
    elseif status != 0
        var detail = output->join(' ')->trim()
        throw detail->empty()
            ? 'github_permalink: could not compare the current file with HEAD'
            : $'github_permalink: {detail}'
    endif
enddef


def GitHubRepository(remote_url: string): string
    var path = ''
    var url = remote_url->trim()

    if url =~# '^git@github\.com:'
        path = url->substitute('^git@github\.com:', '', '')
    elseif url =~# '^\%(https\?://\|git://\|ssh://git@\)github\.com/'
        path = url->substitute('^\%(https\?://\|git://\|ssh://git@\)github\.com/', '', '')
    else
        return ''
    endif

    path = path->substitute('/$', '', '')->substitute('\.git$', '', '')
    return path->split('/')->len() == 2 ? path : ''
enddef


def FindGitHubRepository(root: string): string
    var remotes = Git(root, ['remote'])
    var origin = remotes->index('origin')
    if origin >= 0
        remotes->remove(origin)
        remotes->insert('origin')
    endif

    for remote in remotes
        for url in GitMaybe(root, ['remote', 'get-url', '--all', remote])
            var repository = GitHubRepository(url)
            if !repository->empty()
                return repository
            endif
        endfor
    endfor

    throw 'github_permalink: no remote hosted on github.com was found'
enddef


def EncodeByte(byte: number): string
    return printf('%%%02X', byte)
enddef


def EncodeCharacter(character: number): string
    if character <= 0x7f
        return EncodeByte(character)
    elseif character <= 0x7ff
        return EncodeByte(0xc0 + (character / 0x40))
            .. EncodeByte(0x80 + (character % 0x40))
    elseif character <= 0xffff
        return EncodeByte(0xe0 + (character / 0x1000))
            .. EncodeByte(0x80 + ((character / 0x40) % 0x40))
            .. EncodeByte(0x80 + (character % 0x40))
    endif
    return EncodeByte(0xf0 + (character / 0x40000))
        .. EncodeByte(0x80 + ((character / 0x1000) % 0x40))
        .. EncodeByte(0x80 + ((character / 0x40) % 0x40))
        .. EncodeByte(0x80 + (character % 0x40))
enddef


def EncodePath(path: string): string
    var encoded = ''
    for character in path->str2list(true)
        var is_letter = (character >= char2nr('A') && character <= char2nr('Z'))
            || (character >= char2nr('a') && character <= char2nr('z'))
        var is_digit = character >= char2nr('0') && character <= char2nr('9')
        if is_letter || is_digit || [char2nr('/'), char2nr('.'), char2nr('_'), char2nr('~'), char2nr('-')]->index(character) >= 0
            encoded ..= nr2char(character)
        else
            encoded ..= EncodeCharacter(character)
        endif
    endfor
    return encoded
enddef


def Permalink(first_line: number, last_line: number): string
    var file = expand('%:p')
    if file->empty()
        throw 'github_permalink: the current buffer has no file name'
    endif

    var directory = file->fnamemodify(':h')
    var roots = Git(directory, ['rev-parse', '--show-toplevel'])
    if roots->empty()
        throw 'github_permalink: the current file is not in a git repository'
    endif
    var root = roots[0]->fnamemodify(':p')->resolve()->substitute('/$', '', '')
    var absolute_file = file->fnamemodify(':p')->resolve()
    if absolute_file->stridx(root .. '/') != 0
        throw 'github_permalink: the current file is outside the git repository'
    endif

    var relative_file = absolute_file->strpart(root->len() + 1)
    if &modified
        throw 'github_permalink: save the current buffer before creating a permalink'
    endif
    EnsureFileMatchesHead(root, relative_file)

    var commits = Git(root, ['rev-parse', 'HEAD'])
    if commits->empty()
        throw 'github_permalink: the git repository has no commits'
    endif
    var commit = commits[0]

    # A GitHub permalink can only point to a file present in this commit.
    Git(root, ['cat-file', '-e', $'{commit}:{relative_file}'])

    var repository = FindGitHubRepository(root)
    var start_line = min([first_line, last_line])
    var end_line = max([first_line, last_line])
    var fragment = $'#L{start_line}'
    if end_line != start_line
        fragment ..= $'-L{end_line}'
    endif

    return $'https://github.com/{EncodePath(repository)}/blob/{commit}/{EncodePath(relative_file)}{fragment}'
enddef


def CopyPermalink(first_line: number, last_line: number)
    var url = Permalink(first_line, last_line)
    setreg('"', url)
    if has('clipboard')
        setreg('+', url)
    endif
    echo $'Copied GitHub permalink: {url}'
enddef


command! -range GitHubPermalink CopyPermalink(<line1>, <line2>)
nnoremap <silent> <Plug>(github-permalink) :GitHubPermalink<CR>
xnoremap <silent> <Plug>(github-permalink) :GitHubPermalink<CR>
