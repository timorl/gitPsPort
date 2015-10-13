# fish git prompt support
#
# Copyright (C) 2015 Tomasz Kisielewski <timorl@gmail.com>
# Based on the original __git_ps1 for bash/zsh by
# Shawn O. Pearce <spearce@spearce.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

function __git_ps1_rebase_state
	set -l gitConfigDirectory $argv[1]
	set -l rebaseString ""
	set -l branch ""
	set -l currentRebaseStep ""
	set -l totalRebaseSteps ""
	if [ -d "$gitConfigDirectory/rebase-merge" ]
		read branch < "$gitConfigDirectory/rebase-merge/head-name"
		read currentRebaseStep < "$gitConfigDirectory/rebase-merge/msgnum"
		read totalRebaseSteps < "$gitConfigDirectory/rebase-merge/end"
		if [ -f "$gitConfigDirectory/rebase-merge/interactive" ]
			set rebaseString "|REBASE-i"
		else
			set rebaseString "|REBASE-m"
		end
	else
		if [ -d "$gitConfigDirectory/rebase-apply" ]
			read currentRebaseStep < "$gitConfigDirectory/rebase-apply/next"
			read totalRebaseSteps < "$gitConfigDirectory/rebase-apply/last"
			if [ -f "$gitConfigDirectory/rebase-apply/rebasing" ]
				read branch < "$gitConfigDirectory/rebase-apply/head-name"
				set rebaseString "|REBASE"
			else if [ -f "$gitConfigDirectory/rebase-apply/applying" ]
				set rebaseString "|AM"
			else
				set rebaseString "|AM/REBASE"
			end
		else if [ -f "$gitConfigDirectory/MERGE_HEAD" ]
			set rebaseString "|MERGING"
		else if [ -f "$gitConfigDirectory/CHERRY_PICK_HEAD" ]
			set rebaseString "|CHERRY-PICKING"
		else if [ -f "$gitConfigDirectory/REVERT_HEAD" ]
			set rebaseString "|REVERTING"
		else if [ -f "$gitConfigDirectory/BISECT_LOG" ]
			set rebaseString "|BISECTING"
		end
	end

	if begin; [ -n "$currentRebaseStep" ]; and [ -n "$totalRebaseSteps" ]; end
		set rebaseString "$rebaseString $currentRebaseStep/$totalRebaseSteps"
	end

	echo "$rebaseString"
	echo "$branch"
end

function __git_ps1_branch
	set -l gitConfigDirectory $argv[1]
	set gitDescribeStyle (git config bash.describeStyle ^/dev/null)
	if [ -z "$gitDescribeStyle" ]
		set gitDescribeStyle 'default'
	end

	if [ -h "$gitConfigDirectory/HEAD" ]
		set branch (git symbolic-ref HEAD ^/dev/null)
	else
		read head < "$gitConfigDirectory/HEAD"
		set branch (echo "$head"|sed "s/ref: //")
		if [ "$head" = "$branch" ]
			if [ "$gitDescribeStyle" = "contains" ]
				set branch (git describe --contains HEAD ^/dev/null)
			else if [ "$gitDescribeStyle" = "branch" ]
				set branch (git describe --contains --all HEAD ^/dev/null)
			else if [ "$gitDescribeStyle" = "describe" ]
				set branch (git describe HEAD ^/dev/null)
			else
				set branch (git describe --tags --exact-match HEAD ^/dev/null)
			end

			if [ -z "$branch" ]
				set branch (git rev-parse --short HEAD ^/dev/null)
			end

			set branch "($branch)"
		end
	end
	echo "$branch"
end

function __git_ps1_state
	set gitShowDirtyState (git config bash.showDirtyState ^/dev/null)
	if [ -z "$gitShowDirtyState" ]
		set gitShowDirtyState 'false'
	end
	set gitShowStashState (git config bash.showStashState ^/dev/null)
	if [ -z "$gitShowStashState" ]
		set gitShowStashState 'false'
	end
	set gitShowUntrackedFiles (git config bash.showUntrackedFiles ^/dev/null)
	if [ -z "$gitShowUntrackedFiles" ]
		set gitShowUntrackedFiles 'false'
	end

	if [ "$gitShowDirtyState" = "true" ]
		git	diff --no-ext-diff --quiet --exit-code; or set gitChanges "*"
		if git rev-parse --short HEAD ^/dev/null >/dev/null
			git	diff-index --cached --quiet HEAD --; or set gitAddedChanges "+"
		else
			set gitAddedChanges "#"
		end
	end

	if begin; [ "$gitShowStashState" = "true" ]; and git rev-parse --verify --quiet refs/stash >/dev/null; end
		set gitStashState "\$"
	end

	if begin; [ "$gitShowUntrackedFiles" = "true" ]; and git ls-files --others --exclude-standard --directory --no-empty-directory --error-unmatch -- ':/*' >/dev/null ^/dev/null; end
		set gitUntrackedFiles "%"
	end

	echo "$gitChanges$gitAddedChanges$gitStashState$gitUntrackedFiles"
end

function __git_ps1_show_upstream
	set gitShowUpstream (git config bash.showUpstream ^/dev/null) #Only support auto and verbose for now, no multiple arguments.
	if [ -n "$gitShowUpstream" ]
		set -l counts (git rev-list --count --left-right '@{upstream}'...HEAD ^/dev/null)
		if [ -n "$counts" ]
			set -l behind (echo $counts | sed 's/\t[0-9]*$//')
			set -l ahead (echo $counts | sed 's/^[0-9]*\t//')
			switch "$gitShowUpstream"
				case auto
					if [ "$behind" = "0" ]
						if [ "$ahead" = "0" ]
							echo "="
						else
							echo ">"
						end
					else
						if [ "$ahead" = "0" ]
							echo "<"
						else
							echo "<>"
						end
					end
				case verbose
					if [ "$behind" = "0" ]
						if [ "$ahead" = "0" ]
							echo " u="
						else
							echo " u+$ahead"
						end
					else
						if [ "$ahead" = "0" ]
							echo " u-$behind"
						else
							echo " u+$ahead-$behind"
						end
					end
			end
		end
	end
end

function __git_ps1
	set gitInfoArray (git rev-parse --git-dir --is-inside-git-dir --is-bare-repository --is-inside-work-tree ^/dev/null)
	if [ -n "$gitInfoArray" ]
		set gitConfigDirectory $gitInfoArray[1]
		set gitInsideGitDir $gitInfoArray[2]
		set gitBareRepository $gitInfoArray[3]
		set gitInsideWorktree $gitInfoArray[4]

		set gitHideIfPwdIgnored (git config bash.hideIfPwdIgnored ^/dev/null)
		if [ -z "$gitHideIfPwdIgnored" ]
			set gitHideIfPwdIgnored 'false'
		end

		if begin; [ "$gitInsideWorktree" = "true" ]; and [ "$gitHideIfPwdIgnored" = "true" ]; and git check-ignore -q .; end
			echo "debug"
		else
			set gitStateSeparator (git config bash.stateSeparator ^/dev/null)
			if [ -z "$gitStateSeparator" ]
				set gitStateSeparator ' '
			end

			set -l gitLocalList (__git_ps1_rebase_state "$gitConfigDirectory")
			set gitRebaseString $gitLocalList[1]
			set gitBranch $gitLocalList[2]

			if [ -z "$gitBranch" ]
				set gitBranch (__git_ps1_branch "$gitConfigDirectory")
			end
			set gitBranch (echo "$gitBranch"|sed "s|refs/heads/||")

			if [ "$gitInsideGitDir" = "true" ]
				if [ "$gitBareRepository" = "true" ]
					set gitPrefix "BARE:"
				else
					set gitBranch "GIT_DIR!" # Why?
				end
			else if [ "$gitInsideWorktree" = "true" ]
				set gitStateString (__git_ps1_state)
				set gitUpstreamString (__git_ps1_show_upstream)
			end

			if [ -n "$gitStateString" ]
				set gitStateString "$gitStateSeparator$gitStateString"
			end

			echo "$gitPrefix$gitBranch$gitStateString$gitRebaseString$gitUpstreamString"
		end
	end
end
