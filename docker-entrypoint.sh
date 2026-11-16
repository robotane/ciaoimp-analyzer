#!/bin/bash
# Charge l'environnement Ciao (PATH, CIAOROOT, CIAOENGINE...) puis lance la commande.
eval "$(~/.ciaoroot/v*/build/bin/ciao-env --sh)"
exec "$@"
