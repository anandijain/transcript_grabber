using JSON3, CSV, DataFrames, JSONTables
id_t_fn(t) = "data/ids/$(t)_urls.txt"
function get_ids(cid)
    ts = ["videos", "shorts", "streams"]
    for t in ts
        url = "https://www.youtube.com/channel/$(cid)/$(t)"
        command = `yt-dlp --flat-playlist --print "%(id)s" "$(url)"`
        run(pipeline(command, stdout=joinpath(@__DIR__, id_t_fn(t))))
    end
end
grab_cmd(id_fn) = `yt-dlp --write-info-json --write-auto-subs --skip-download -a $id_fn`
get_video_id(s) = s[only(findlast("[", s))+1:only(findlast("]", s))-1]

function getdskip(d, ks)
    vs = []
    for k in ks
        !haskey(d, k) && continue
        push!(vs, d[k])
    end
    vs
end
function parse_segment(s)
    if !haskey(s, "tOffsetMs")
        offset = 0
    else
        offset = s.tOffsetMs
    end
    utf8 = s.utf8
    (offset, utf8)
end

function parse_event(e)
    !haskey(e, "segs") && return []
    t0 = e.tStartMs
    pss = parse_segment.(e.segs)
    map(x -> (x[1] + t0, x[2]), pss)
end

f(x) = x.formats[1].fragments[1].duration
get_timestamped_words(j) = reduce(vcat, parse_event.(j.events))
get_txt_transcipt(timestamped_words::Vector) = join(last.(timestamped_words))
get_txt_transcipt(j) = get_txt_transcipt(get_timestamped_words(j))

get_event_transcript(e) = ((e.tStartMs, e.tStartMs + e.dDurationMs), join(map(x -> x["utf8"], e.segs)))
get_events_transcript(j) = get_event_transcript.(j.events[2:end])

function token_tally(enc, txt)
    e = enc.encode(txt)
    v = pyconvert(Vector{Integer}, e)
    t = tally(v)
    map(x -> string(enc.decode([x[1]])) => x[2], t)
end
function get_json_transcript(url)
    subtitle_file = "temp_subtitle"  # Temporary file name
    run(`yt-dlp --sub-format json3 --write-auto-subs --skip-download --output $subtitle_file $url`)
    fn = subtitle_file * ".en.json3"
    transcript = read(fn, String)
    rm(fn)
    return JSON3.read(transcript)
end

# example https://www.youtube.com/playlist?list=PL79kqjVnD2EPVIWg-ihbN_tPdFki3OzMf
function get_playlist_ids(url)
    command = `yt-dlp --flat-playlist --print "%(id)s" "$(url)"`
    split(read(command, String))
end


mkpath(joinpath(@__DIR__, "./data/ids"))
mkpath(joinpath(@__DIR__, "./data/transcripts"))
mkpath(joinpath(@__DIR__, "./data/metadata"))


cid = "UCnKJ-ERcOd3wTpG7gA5OI_g"

ids = reduce(vcat, readlines.(id_fn.(ts)))
all_id_fn = "data/ids/ids.txt"
write(joinpath(@__DIR__, all_id_fn), join(ids, '\n'))


grab = grab_cmd(all_id_fn)
# run(`grab`) # just run this in command line 

j_ex = "C:/Users/anand/src/transcript_grabber/data/metadata/locking in： de anza dmt 80 exam 2 review [OHplC-nztVI].info.json"
jex2 = "C:/Users/anand/src/transcript_grabber/data/metadata/pitch assembly and 2 motor control [uamfAMClo8A].info.json"
j = JSON3.read(read(j_ex))
j2 = JSON3.read(read(jex2))

# throws where j and j2 one is video other is stream `release_timestamp keyerror`
# df = DataFrame([j, j2])

mfns = readdir("data/metadata/"; join=true)
ms = @. JSON3.read(read(mfns));
ids = get_video_id.(mfns)
txts = ids .=> ms;
dtxts = Dict(txts)

vidids = readlines(id_t_fn("videos"))
vidjs = getd(dtxts, vidids)
# df = DataFrame(vidjs)

ks = collect(intersect(keys.(vidjs)...))

j = vidjs[1]
ds = map(x -> getd(x, ks), vidjs)
x = permutedims(reduce(hcat, ds))
df = DataFrame(Tables.table(x; header=ks))

CSV.write("meta.csv", df)

cols = [:id,
    :title,
    :view_count,
    :duration,
    :timestamp,
    :like_count,
    :categories,
    :filesize_approx]

d = df[:, cols]
sort!(d, :duration; rev=true)
sort!(d, :like_count; rev=true)



sids = readlines(id_t_fn("streams"))
sjs = getdskip(dtxts, sids)

sks = collect(intersect(keys.(sjs[2:end])...))
print(sks)

sds = map(x -> getd(x, sks), sjs[2:end])
sdf = DataFrame(Tables.table(permutedims(reduce(hcat, sds)); header=sks))
ss = sdf[:, cols]
sort!(ss, :view_count; rev=true)


fns = filter(endswith(".json3"), readdir("data/transcripts"; join=true))
ids = get_video_id.(fns)
js = @. JSON3.read(read(fns));
j = js[1]
ts = get_txt_transcipt.(js);
txts = ids .=> ts;
dtxts = Dict(txts)
evs = j.events[2:end]


write("dataset.txt", join(last.(txts)))

# yt-dlp --sub-format json3 --write-auto-subs --skip-download https://www.youtube.com/watch?v=Sqr-PdVYhY4
url = "https://www.youtube.com/watch?v=Sqr-PdVYhY4"
j = get_json_transcript(url)
t = get_txt_transcipt(j)