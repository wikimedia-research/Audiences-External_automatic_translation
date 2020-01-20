# Measure the impact of external automatic translation services

This is the repository of the notebook ["Measure the impact of external automatic translation services
"](https://analytics.wikimedia.org/datasets/external-automatic-translation/impact%20of%20external%20automatic%20translation%20services.html). This notebook is currently updating daily at 2AM UTC on [notebook1004](https://wikitech.wikimedia.org/wiki/SWAP) -- cron job: 
```
0 2 * * * /home/<username>/external-automatic-translation/update_publish_notebook.sh
```
Please remember to add [http proxy variables](https://wikitech.wikimedia.org/wiki/HTTP_proxy) before running the notebook. And check the `/home/<username>/external-automatic-translation/notebook_update.log` file if you run into bugs.

The `toledo_pageviews oozie job` folder contains code used to update the `toledo_pageviews` table on HDFS. It filters and aggregates data from `wmf.webrequest` on a daily basis to get the pageviews from external automatic translation services. Please refer to [wikitech](https://wikitech.wikimedia.org/wiki/Analytics/Systems/Cluster/Oozie) about how to deploy an oozie job.

If changing ownership is needed, please see [T228195](https://phabricator.wikimedia.org/T228195) for more instructions.

If you have any comments or questions, please leave your feedback in the ticket: https://phabricator.wikimedia.org/T212414