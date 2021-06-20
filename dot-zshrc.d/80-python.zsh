export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"