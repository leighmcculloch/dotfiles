#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

brew install --formula \
$(brew leaves | sed 's/$/ \\/g')
;" > install-deps.sh
