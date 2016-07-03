install:
	ln -sf $$PWD/tmux.conf $$HOME/.tmux.conf
	ln -sf $$PWD/tmux      $$HOME/.tmux
	tmux new-session "tmux source ~/.tmux.conf"
