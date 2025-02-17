using JSON3, CSV, DataFrames, JSONTables
id_t_fn(t) = "data/ids/$(t)_urls.txt"
ALL_ID_FN = "data/ids/ids.txt"

const VIDEO_TYPES = ["videos", "shorts", "streams"]
function get_ids(cid; ts=VIDEO_TYPES)
    for t in ts
        url = "https://www.youtube.com/channel/$(cid)/$(t)"
        command = `yt-dlp --flat-playlist --print "%(id)s" "$(url)"`
        run(pipeline(command, stdout=joinpath(@__DIR__, id_t_fn(t))))
    end
    ids = read_ids_from_files(ts)
    write(joinpath(@__DIR__, ALL_ID_FN), join(ids, '\n'))
    ids
end


read_ids_from_files(ts=VIDEO_TYPES) = reduce(vcat, readlines.(id_t_fn.(ts)))

grab_cmd(id_fn) = `yt-dlp --write-info-json --write-auto-subs --sub-format json3 --skip-download -a $id_fn`
grab_one_cmd(id::String) = begin
    url = "https://www.youtube.com/watch?v=" * id
    `yt-dlp --write-info-json --write-auto-subs --sub-format json3 --skip-download $url`
end

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

grab_subtitles_cmd(id) = begin
    url = "https://www.youtube.com/watch?v=" * id
    `yt-dlp --write-auto-subs --sub-format json3 --skip-download $url`
end

grab_metadata_cmd(id) = begin
    url = "https://www.youtube.com/watch?v=" * id
    `yt-dlp --write-info-json --skip-download $url`
end

function get_missing_ids(ids; transcripts_dir, metadata_dir)
    transcript_files = readdir(transcripts_dir)
    metadata_files = readdir(metadata_dir)
    missing_metadata = String[]
    missing_transcripts = String[]
    for id in ids
        if !any(f -> occursin(id, f) && endswith(f, ".info.json"), metadata_files)
            push!(missing_metadata, id)
        end
        if !any(f -> occursin(id, f) && endswith(f, ".en.json3"), transcript_files)
            push!(missing_transcripts, id)
        end
    end
    (missing_metadata, missing_transcripts)
end

function process_missing_ids(missing_metadata, missing_transcripts)
    metadata_dir = joinpath(@__DIR__, "data", "metadata")
    transcripts_dir = joinpath(@__DIR__, "data", "transcripts")
    missing_file = joinpath(@__DIR__, "data", "ids", "no_transcripts.txt")
    no_transcript_ids = readlines(missing_file)
    for id in missing_metadata
        output = read(grab_metadata_cmd(id), String)
        println(output)
        for file in readdir(@__DIR__)
            if occursin(id, file) && endswith(file, ".info.json")
                mv(joinpath(@__DIR__, file), joinpath(metadata_dir, file))
            end
        end
    end
    for id in missing_transcripts
        if id ∈ no_transcript_ids
            @show  "skipping an id" id 
            continue
        end
        output = read(grab_subtitles_cmd(id), String)
        println(output)

        if occursin("no subtitles", lowercase(output))
            push!(no_transcript_ids, id)
        else
            for file in readdir(@__DIR__)
                if occursin(id, file) && endswith(file, ".en.json3")
                    mv(joinpath(@__DIR__, file), joinpath(transcripts_dir, file))
                end
            end
        end
    end
    write(missing_file, join(no_transcript_ids, "\n"))
    (missing_metadata, missing_transcripts, no_transcript_ids)
end


mkpath(joinpath(@__DIR__, "./data/ids"))
mkpath(joinpath(@__DIR__, "./data/transcripts"))
mkpath(joinpath(@__DIR__, "./data/metadata"))


cid = "UCnKJ-ERcOd3wTpG7gA5OI_g"
# ids = get_ids(cid)
ids = read_ids_from_files()

# Define paths relative to @__DIR__
ids_file = joinpath(@__DIR__, "data", "ids", "ids.txt")
transcripts_dir = joinpath(@__DIR__, "data", "transcripts")
metadata_dir = joinpath(@__DIR__, "data", "metadata")

# missing_ids = get_missing_ids(ids_file; transcripts_dir=transcripts_dir, metadata_dir=metadata_dir)
missing_ids = get_missing_ids(ids; transcripts_dir=transcripts_dir, metadata_dir=metadata_dir)
# missing_ids_file = joinpath(@__DIR__, "data", "ids", "missing_ids.txt")
# write(missing_ids_file, join(missing_ids, "\n"))

grab = process_missing_ids(missing_ids...)
rm(missing_ids_file)

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
ks = filter(x -> x != :formats, ks)
ks = filter(x -> x != :automatic_captions, ks)
j = vidjs[1]
ds = map(x -> getd(x, ks), vidjs)
x = permutedims(reduce(hcat, ds))
df = DataFrame(Tables.table(x; header=ks))

CSV.write("data/meta.csv", df)

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

# building dataset
fns = filter(endswith(".json3"), readdir("data/transcripts"; join=true))
ids = get_video_id.(fns)
js = @. JSON3.read(read(fns));
j = js[1]
ts = get_txt_transcipt.(js);
txts = ids .=> ts;
dtxts = Dict(txts)
evs = j.events[2:end]

write("data/dataset.txt", join(last.(txts)))


# yt-dlp --sub-format json3 --write-auto-subs --skip-download https://www.youtube.com/watch?v=Sqr-PdVYhY4
url = "https://www.youtube.com/watch?v=Sqr-PdVYhY4"
j = get_json_transcript(url)
t = get_txt_transcipt(j)