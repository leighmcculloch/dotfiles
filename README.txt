After cloning this project, you can run the following to link these dotfiles
into your home directory:

    rake

Be warned: this will overwrite any existing .vimrc, .gvimrc or .vim/ files you
have in your home directory.

Uses `vim-plug` to manage bundles. Downloading and setting up the described
plugins requires an extra step:

    vim +:PlugInstall
