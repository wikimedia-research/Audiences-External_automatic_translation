#!/home/chelsyx/venv/bin/python3

from datetime import datetime, timedelta
from wmfdata import hive # pip install git+https://github.com/neilpquinn/wmfdata.git
import time
import mwapi
import pandas as pd
from proj_utils import active_wikis
import mwreverts.api

current_date = datetime.utcnow()
start_date=current_date - timedelta(days=7)

def check_reverted_api(api_session, rev_id, page_id):
    _, reverted, _ = mwreverts.api.check(
        api_session, rev_id=rev_id, page_id=page_id,
        radius=10, window=7 * 24 * 60 * 60)
    return (reverted is not None)

# Query all the revisions from external-machine-translation

query_vars = dict(
    end_date=current_date.strftime("%Y-%m-%d"),
    start_date=start_date.strftime("%Y-%m-%d"),
    end_year = current_date.year,
    start_year = start_date.year
    )
query = """
select distinct substr(t.rev_timestamp, 0, 10) AS date,
r.`database` as wiki,
r.rev_id,
r.page_namespace,
r.page_id
from event.mediawiki_revision_tags_change t right outer join event.mediawiki_revision_create r 
     on (t.rev_id = r.rev_id 
        and r.page_id = t.page_id
        and r.`database`=t.`database`
        and r.page_namespace = t.page_namespace
        and t.year>='{start_year}' and t.year<='{end_year}')
where r.year>='{start_year}' and r.year<='{end_year}'
and substr(r.rev_timestamp, 0, 10) >= '{start_date}'
and substr(r.rev_timestamp, 0, 10) < '{end_date}'
and r.meta.domain like '%wikipedia%'
and not r.performer.user_is_bot
and not array_contains(r.performer.user_groups, 'bot')
and array_contains(t.tags, "campaign-external-machine-translation")
-- and r.rev_parent_id is not NULL
order by date asc
limit 1000000
"""
query = query.format(**query_vars)
print('Querying edits from external machinetranslation...')
new_edits = hive.run(query)

all_edits = pd.read_csv('/home/chelsyx/external-automatic-translation/external_machine_translation_edits_revert.tsv',sep='\t')
all_edits = all_edits[all_edits.date < start_date.strftime("%Y-%m-%d")]

# Loop through all distinct wiki and check revert

print('Checking revert...')
for wiki in new_edits.wiki.unique():

    print(wiki + ' start!')
    init = time.perf_counter()
    tempdf = new_edits[new_edits.wiki == wiki].copy()
    tempdf['language'] = active_wikis.language_name[active_wikis.dbname == wiki].to_string(index=False)
    tempdf['is_reverted'] = None

    api_session = mwapi.Session(active_wikis.url[active_wikis.dbname == wiki].to_string(
        index=False), user_agent="Revert detection <cxie@wikimedia.org>")
    for row in tempdf.itertuples():
        try:
            tempdf.at[row.Index, 'is_reverted'] = check_reverted_api(api_session, row.rev_id, row.page_id)
        except mwapi.errors.APIError:
            print("API error: revision " + str(row.rev_id))
            continue
        except KeyError:
            tempdf.at[row.Index, 'is_reverted'] = True

    # append to all_edits data frame
    all_edits = all_edits.append(tempdf, ignore_index=True)
    elapsed = time.perf_counter() - init
    print("{} completed in {:0.0f} s".format(wiki, elapsed))


all_edits = all_edits.sort_values('date')
all_edits.to_csv(
    '/home/chelsyx/external-automatic-translation/external_machine_translation_edits_revert.tsv',
    sep='\t',
    index=False)
