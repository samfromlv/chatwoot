#check that run under chatwoot user
if [ "$(whoami)" != "chatwoot" ]; then
    echo "This script must be run as chatwoot user"
    exit 1
fi

bundle
yarn install
rake assets:precompile RAILS_ENV=production