using JSON3, Plots #, CondaPkg, PythonCall, Plots
Base.haskey(x) = y -> Base.haskey(y, x)
Base.get(x) = y -> Base.get(y, x)
# its interesting to think about which functions have a natural way to curry
# i would never write Base.get(x) = y -> Base.get(x, y)
tt = pyimport("tiktoken")
enc = tt.get_encoding("o200k_base")

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

# fix this
get_video_id(s) = s[only(findlast("[", s))+1:only(findlast("]", s))-1]

fns = filter(endswith(".json3"), readdir("data/transcripts"; join=true))

js = @. JSON3.read(read(fns));
durs = []

g, b = goodbad(x -> f(x[2]), zip(fns, js));
sum(last.(g))

fn = "data/json_transcripts/i spent 8 HOURS in onshape [K2OsuCs2YrE].en.json3"

fns2 = filter(endswith(".json3"), readdir("data/json_transcripts/"; join=true))

# write("eight_hours.txt", join(last.(data)))
js2 = @. JSON3.read(read(fns2));
j = JSON3.read(read(fn))
evs = j.events[2:end]

tally(haskey("dDurationMs").(evs)) # :/ 
tally(map(length ∘ get("segs"), evs))

ts = get_txt_transcipt.(js2);
ids = get_video_id.(fns2)
txts = ids .=> ts;
dtxts = Dict(txts)
longs = sort(txts; by=length ∘ last, rev=true);
# id K2OsuCs2YrE

encs = enc.encode.(last.(txts))

# need to split by live 
# also want to know the words per minute on average of streams
histogram(length.(encs))

data = token_tally.(enc, last.(txts));
ds = Dict.(data)
m = mergewith(+, ds...)
bigp = collect(m)
sortl!(bigp)
plot(last.(bigp))


map(println, first(bigp, 200));

tvids = get_video_id.(fns2)
tvid = tvids[1]
vid_to_mfn(fns, vid) = fns[only(findall(x -> occursin(vid, x), fns))]
vid = tvid
fns[only(findall(x -> occursin(vid, x), fns))]