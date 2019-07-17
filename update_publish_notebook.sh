#!/bin/bash

cd /home/neilpquinn-wmf
{ source .bash_profile
  date
  external-automatic-translation/fetch_edit_check_revert.py
  venv/bin/jupyter nbconvert --ExecutePreprocessor.timeout=600 --execute --to html external-automatic-translation/impact\ of\ external\ automatic\ translation\ services.ipynb
  cp external-automatic-translation/impact\ of\ external\ automatic\ translation\ services.html /srv/published-datasets/external-automatic-translation
} >> /home/neilpquinn-wmf/external-automatic-translation/notebook_update.log 2>&1
