# thx to https://github.com/mduvall/config/

function subl --description 'Open Sublime Text'
  if test -d "/Applications/Sublime Text.app"
    "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" $argv
  else if test -d "/Applications/Sublime Text 2.app"
    "/Applications/Sublime Text 2.app/Contents/SharedSupport/bin/subl" $argv
  else if test -x "/opt/sublime_text/sublime_text"
    "/opt/sublime_text/sublime_text" $argv
  else if test -x "/opt/sublime_text_3/sublime_text"
    "/opt/sublime_text_3/sublime_text" $argv
  else
    echo "No Sublime Text installation found"
  end
end


function kill_process --description 'Kill process that user selects in fzf (from ps aux output)'
  set -l pid (ps aux | fzf -m --header-lines=1 | awk '{print $2}')

  if test -n "$pid"
    echo "Killing processes: $pid"
    kill -9 $pid
  end
end


function kill_port --description 'Select a port to kill, by pid, port, or command line'

  # Function to get the command line for a given PID
  function get_command -a pid
    ps -p $pid | awk 'NR>1 {for (i=4; i<=NF; i++) {printf "%s ", $i}; print ""}'
  end

  # Find listening processes, get commands, and format output
  lsof -iTCP -sTCP:LISTEN -P | awk '{print $2, $9}' | uniq | tail -n +2 | \
    while read -l pid port
      set -l command (get_command $pid)
      set -l port (string pad -w 8 (string replace 'localhost' '' $port))
      set -l pid (string pad --right -w 6 $pid)
      echo -e "$pid $port $command"  | column
    end | \

    # Pipe the output to fzf for selection. Grab pid and show pstree
    fzf --exact --tac --preview 'pstree -p (echo {} | awk "{print $2}")' --preview-window=down,30% --header "Select a process to kill (PID Command Port):" | \

    # Kill the selected process
    awk '{print $1}' | xargs -r kill -9
end


function clone --description "clone something, cd into it. install it."
    git clone --depth=1 $argv[1]
    cd (basename $argv[1] | sed 's/.git$//')
    yarn install
end


function renameurldecode
    for file in *
        set -l original $file
        set -l decoded (python3 -c "import urllib.parse; print(urllib.parse.unquote_plus('$original'))")
        if test "$original" != "$decoded"
            mv "$original" "$decoded"
        end
    end
end

function notif --description "make a macos notification that the prev command is done running"
  #  osascript -e 'display notification "hello world!" with title "Greeting" sound name "Submarine"'
  osascript \
    -e "on run(argv)" \
    -e "return display notification item 1 of argv with title \"command done\" sound name \"Submarine\"" \
    -e "end" \
    -- "$history[1]"
end

function beep --description "make two beeps"
  echo -e '\a'; sleep 0.1; echo -e '\a';
end

function all_binaries_in_path --description \
  "list all binaries available in \$PATH (incl conflicts). pipe it to grep. top-most are what's used, in case of conflicts"
  # based on https://unix.stackexchange.com/a/120790/110766 but tweaked to work on mac. and then made it faster.
  find -L $PATH -maxdepth 1 -executable -type f 2>/dev/null

  # list path
  # for val in $PATH; echo "$val"; end
end

function list_path --description "list all paths in PATH"
  for val in $PATH; echo "$val"; end
end

function my_paths --description "list paths, in order"
  echo "#  "
  printf '%s\n' (string split \n $PATH)
end

function stab --description "stabalize a video"
  set -l vid $argv[1]
  ffmpeg -i "$vid" -vf vidstabdetect=stepsize=32:result="$vid.trf" -f null -;
  ffmpeg -i "$vid" -b:v 5700K -vf vidstabtransform=interpol=bicubic:input="$vid.trf" "$vid.mkv";  # :optzoom=2 seems nice in theory but i dont love it. kinda want a combo of 1 and 2. (dont zoom in past the static zoom level, but adaptively zoom out to full when possible)
  ffmpeg -i "$vid" -i "$vid.mkv" -b:v 3000K -filter_complex hstack "$vid.stack.mkv"
  # vid=Dalton1990/Paultakingusaroundthehouseagai ffmpeg -i "$vid.mp4" -i "$vid.mkv" -b:v 3000K -filter_complex hstack $HOME/Movies/"Paultakingusaroundthehouseagai.stack.mkv"
  command rm $vid.trf
end


function md --wraps mkdir -d "Create a directory and cd into it"
  command mkdir -p $argv
  if test $status = 0
    switch $argv[(count $argv)]
      case '-*'
      case '*'
        cd $argv[(count $argv)]
        return
    end
  end
end

# print compression results with a bar chart
function gz --d "Get the gzipped size"
  set -l file "$argv[1]"
  set -l orig_size (cat "$file" | wc -c)

  printf "\e[1;97m%-20s %12s\e[0m\n" "compression method" "bytes"

  for method in \
    "original" \
    # Gzip CLI default is -6, but GH pages only uses -5. Dunno about others.
    "gzip (-5)" \
    # "gzip (--best)" \
    # (test (command -v zstd) && echo "zstd (-3)") \
    (test (command -v zstd) && echo "zstd") \
    (test (command -v brotli) && echo "brotli (-q 5)") # brotli is last because its compressor is sloowww
    
    printf "%-20s " "$method" 

    set -l compressed_size (
      switch "$method"
        case "original"
          cat "$file" | wc -c
        case "gzip (-5)"
          cat "$file" | gzip -5 -c | wc -c
        case "gzip (--best)"
          cat "$file" | gzip --best -c | wc -c
        case "brotli (-q 5)"
          cat "$file" | brotli -c  | wc -c
        case "zstd"
          # If experimenting, could also do --19 or --22 --ultra
          cat "$file" | zstd -c - | wc -c
        case '*'
          echo "Unhandled case. $method"
      end
    )
    set -l wid (math $COLUMNS - 40)
    set -l bar_width (math -s0 $compressed_size \* $wid / $orig_size)
    printf "%'12.0f   %s%s\n" "$compressed_size" (string repeat -n $bar_width '█') (string repeat -n (math -s0 "$wid - $bar_width")  '░')
  end
end

function sudo!!
    eval sudo $history[1]
end


# `shellswitch [bash|zsh|fish]`
function shellswitch
	chsh -s (brew --prefix)/bin/$argv
end

function maxcpu100 -d "literally max out all your cores."
  echo "To stop the pain run:"
  echo "killall yes"
  for i in (seq (nproc)); yes >/dev/null & end
end

# requires my excellent `npm install -g statikk`
function server -d 'Start a HTTP server in the current dir, optionally specifying the port'
    # arg can either be port number or extra args to statikk
    if test $argv[1]
      if string match -qr '^-?[0-9]+(\.?[0-9]*)?$' -- "$argv[1]"
        set port $argv[1]
        # fancy argv thing to pass all remaining args. eg `server --cors --jsprof`
        statikk --open --port $argv[1..-1]
      else
        statikk --open $argv[1..-1]
      end

    else
        statikk --open
    end
end


function conda -d 'lazy initialize conda'
  functions --erase conda
  eval /opt/miniconda3/bin/conda "shell.fish" "hook" | source
  # There's some opportunity to use `psub` but I don't really understand it.
  conda $argv
end

# NVM doesnt support fish and its stupid to try to make it work there.


function google_cloud_sdk_lazy_init -d 'Lazy initializer for Google Cloud SDK'
  functions --erase gcloud gsutil bq
  source "$HOME/google-cloud-sdk/path.fish.inc"
  $argv
end
for cmd in gcloud gsutil bq
  eval "function $cmd; google_cloud_sdk_lazy_init $cmd \$argv; end"
end
