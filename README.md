# transcript_grabber

given a youtube channel id, grab all of their transcripts 

```
yt-dlp --flat-playlist --print "%(id)s" "https://www.youtube.com/channel/UCnKJ-ERcOd3wTpG7gA5OI_g/videos" > video_urls.txt
yt-dlp --flat-playlist --print "%(id)s" "https://www.youtube.com/channel/UCnKJ-ERcOd3wTpG7gA5OI_g/shorts" > shorts_urls.txt
yt-dlp --flat-playlist --print "%(id)s" "https://www.youtube.com/channel/UCnKJ-ERcOd3wTpG7gA5OI_g/streams" > streams_urls.txt
cat video_urls.txt shorts_urls.txt streams_urls.txt > all_urls.txt
yt-dlp --write-info-json --write-auto-subs --skip-download -a all_urls.txt
```

yt-dlp --write-info-json --skip-download -a data/ids/ids.txt -P data/metadata


yt-dlp --sub-format json3 --write-auto-subs --skip-download -a data/ids/ids.txt -P data/transcripts

i wish this was way faster and multithreaded 