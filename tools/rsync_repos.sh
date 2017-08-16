#!/usr/bin/env bash

SCRIPT_DIR="$(cd $(dirname $0) && pwd)";
WEBSITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)";
REPO_DIR_NAME="repo";
REPO_DIR="$(cd "$WEBSITE_DIR/$REPO_DIR_NAME" && pwd)";
STATUS_FILE="$SCRIPT_DIR/sync.status.xml";
LOG_DIR="$SCRIPT_DIR/logs";
RSYNC_OPTIONS="-rlptDvz";

mkdir -p "$LOG_DIR";

function calc_size() {
    if [ 0 -eq $# ]; then
        echo "0B";
        return;
    fi

    SZ=$1;
    # 16GB=>GB
    if [ $SZ -gt 17179869184 ]; then
        echo "$(($SZ/1073741824))GB";
        return;
    fi

    # 16MB=>MB
    if [ $SZ -gt 16777216 ]; then
        echo "$(($SZ/1048576))MB";
        return;
    fi

    # 16KB=>KB
    if [ $SZ -gt 65536 ]; then
        echo "$(($SZ/1024))MB";
        return;
    fi

    echo "${SZ}B";
    return;
}

while read line  || [[ -n ${line} ]] ; do
    REPO_NAME=$(echo "$line" | awk '{print $1}');
    if [ -z "$REPO_NAME" ] || [ '#' == "${REPO_NAME:0:1}" ] || [ '//' == "${REPO_NAME:0:2}" ] || [ ';' == "${REPO_NAME:0:1}" ]; then
        continue
    fi
    # default configure
    REMOTE_PATH="";
    LOCAL_PATH="$REPO_NAME";
    REPO_TTL_TIMEOUT="1h";
    REPO_TTL=3;
    REPO_URL=();
    REPO_RSYNC_OPTIONS="";
    REPO_TOOL="rsync";
    for KV in $line; do
        if [ "$KV" == "$REPO_NAME" ]; then
            continue
        fi
        KEY="${KV/=*}";
        VAL="${KV#*=}";

        while [ '//' == "${VAL:0:2}" ]; do
            VAL="${VAL:1}";
        done

        if [ "REMOTE_PATH" == "$KEY" ]; then
            REMOTE_PATH="$VAL";
        elif [ "LOCAL_PATH" == "$KEY" ]; then
            LOCAL_PATH="$VAL";
        elif [ "REPO_TTL_TIMEOUT" == "$KEY" ]; then
            REPO_TTL_TIMEOUT="$VAL";
        elif [ "REPO_TTL" == "$KEY" ]; then
            REPO_TTL=$VAL;
        elif [ "REPO_URL" == "$KEY" ]; then
            REPO_URL+=("$VAL");
        elif [ "REPO_RSYNC_OPTIONS" == "$KEY" ]; then
            REPO_RSYNC_OPTIONS="$REPO_RSYNC_OPTIONS $VAL";
        elif [ "REPO_TOOL" == "$KEY" ]; then
            REPO_TOOL="$VAL";
        fi
    done

    if [ 0 -eq ${#REPO_URL} ]; then
        continue;
    fi

    # start logic
    SYNC_TIME=$(date "+%F %T");
    STATUS_MSG="Repo Not Found";

    MAIN_LOG_FILE="$LOG_DIR/$REPO_TOOL.$REPO_NAME.log";
    URL_LOG_NAME="$(realpath --relative-base="$WEBSITE_DIR" "$MAIN_LOG_FILE")";
    PARTIAL_DIR="$SCRIPT_DIR/cache/$REPO_NAME";
    mkdir -p "$PARTIAL_DIR";
    echo "[$SYNC_TIME]: start sync $REPO_NAME from $REMOTE_PATH(@[REPO_URL]) into $LOCAL_PATH ..." > "$MAIN_LOG_FILE";
    STATUS_DETAIL="";

    for SRC_URL in ${REPO_URL[@]}; do
        if [ -z "$SRC_URL" ]; then
            break;
        fi
        LOCAL_PATH_ABS="$REPO_DIR/$LOCAL_PATH";
        URL_PATH="$REPO_DIR_NAME/$LOCAL_PATH";
        if [ ! -e "$LOCAL_PATH_ABS" ]; then
            mkdir -p "$LOCAL_PATH_ABS";
        fi

        STATUS_MSG="";
        TOTAL_SIZE=$(grep "<repo name=\"$REPO_NAME\"" "$STATUS_FILE" | perl -n -e "/total_size=\"([^\"]*)\"/ && print \$1");
        LAST_SPEED=$(grep "<repo name=\"$REPO_NAME\"" "$STATUS_FILE" | perl -n -e "/speed=\"([^\"]*)\"/ && print \$1");
        SYNC_TIME_START_UNIX=$(date "+%s");

        if [ -z "$TOTAL_SIZE" ]; then
            TOTAL_SIZE=$(du -sb "$LOCAL_PATH_ABS" | tail -n1 | awk '{print $1}');
        fi

        sed -i "/<repo name=\"$REPO_NAME\"/d" "$STATUS_FILE";
        sed -i "/<repos>\\s*/a <repo name=\"$REPO_NAME\" update=\"$SYNC_TIME\" status=\"Running\" status_detail=\"Running rsync with options $RSYNC_OPTIONS $REPO_RSYNC_OPTIONS\" url=\"$URL_PATH\" src=\"$SRC_URL\" log=\"$URL_LOG_NAME\" total_size=\"$TOTAL_SIZE\" speed=\"$LAST_SPEED\" />" "$STATUS_FILE";

        TTL=$REPO_TTL;
        while [ $TTL -gt 0 ]; do
            SYNC_TIME=$(date "+%F %T");
            if [ "$REPO_TOOL" == "rsync" ]; then
                REMOTE_PATH_ABS="$SRC_URL/$REMOTE_PATH";
                echo "[$SYNC_TIME][TTL=$TTL]: timeout $REPO_TTL_TIMEOUT rsync --partial --partial-dir=\"$PARTIAL_DIR\" --log-file=\"$MAIN_LOG_FILE\" $RSYNC_OPTIONS $REPO_RSYNC_OPTIONS \"$REMOTE_PATH_ABS\" \"$LOCAL_PATH_ABS\"" >> "$MAIN_LOG_FILE";
                timeout $REPO_TTL_TIMEOUT rsync --partial --partial-dir="$PARTIAL_DIR" --log-file="$MAIN_LOG_FILE" $RSYNC_OPTIONS $REPO_RSYNC_OPTIONS "$REMOTE_PATH_ABS" "$LOCAL_PATH_ABS";
            elif [ "$REPO_TOOL" == "apt-mirror" ]; then
                if [ ! -e "$SCRIPT_DIR/apt-mirror" ]; then
                    git clone -b master https://github.com/apt-mirror/apt-mirror.git "$SCRIPT_DIR/apt-mirror";
                else
                    $(cd "$SCRIPT_DIR/apt-mirror/" && git reset --hard && git clean -dfx && git pull);
                fi
                chmod +x "$SCRIPT_DIR/apt-mirror/apt-mirror";
                echo "[$SYNC_TIME][TTL=$TTL]: timeout $REPO_TTL_TIMEOUT \"$SCRIPT_DIR/apt-mirror/apt-mirror\" \"$REMOTE_PATH\"" >> "$MAIN_LOG_FILE";
                timeout $REPO_TTL_TIMEOUT "$SCRIPT_DIR/apt-mirror/apt-mirror" "$REMOTE_PATH" >> "$MAIN_LOG_FILE" 2>&1 ;
            else
                STATUS_MSG="Unknown tool $REPO_TOOL";
            fi
            RET_CODE=$?;
            # RET_CODE=1;
            echo "[$SYNC_TIME][TTL=$TTL]: rsync existed with return code = $RET_CODE" >> "$MAIN_LOG_FILE";
            if [ 0 -eq $RET_CODE ]; then
                STATUS_MSG="Success";
                break;
            elif [ 124 -eq $RET_CODE ]; then
                # timeout, retry
                let TTL=$TTL-1;
            elif [ 128 -le $RET_CODE ]; then
                # killed by signal 
                STATUS_MSG="Killed by external service";
                break;
            else
                break;
            fi
        done

        STATUS_DETAIL="$(tail -n3 "$MAIN_LOG_FILE")";
        if [ ! -z "$STATUS_MSG" ]; then
            break;
        fi

        if [ $TTL -le 0 ]; then
            STATUS_MSG="Timeout";
        else
            STATUS_MSG="Failed";
            STATUS_DETAIL="$(tail -n10 "$MAIN_LOG_FILE" | grep -i \"ERROR:\")";
        fi
    done
    SYNC_TIME=$(date "+%F %T");
    echo "[$SYNC_TIME]: sync $REPO_NAME from $REMOTE_PATH(@[REPO_URL]) into $LOCAL_PATH done. status=$STATUS_MSG" >> "$MAIN_LOG_FILE";
    
    OLD_SIZE=$TOTAL_SIZE;
    TOTAL_SIZE=$(tail -n6 "$MAIN_LOG_FILE" | perl -n -e "/total\\s*size\\s*is\\s*([0-9]+)/ && print \$1");
    if [ -z "$TOTAL_SIZE" ]; then
        TOTAL_SIZE=$(du -sb "$LOCAL_PATH_ABS" | tail -n1 | awk '{print $1}');
    fi
    LAST_SPEED=$(tail -n6 "$MAIN_LOG_FILE" | perl -n -e "/([0-9]+)(\\.[0-9]*)?\\s*bytes\\/sec/ && print \$1");
    if [ -z "$LAST_SPEED" ]; then
        SYNC_TIME_END_UNIX=$(date "+%s");
        if [ $SYNC_TIME_END_UNIX -gt $SYNC_TIME_START_UNIX ]; then
            LAST_SPEED=$((($TOTAL_SIZE-$OLD_SIZE)/($SYNC_TIME_END_UNIX-$SYNC_TIME_START_UNIX)));
        else
            LAST_SPEED=$(($TOTAL_SIZE-$OLD_SIZE));
        fi
    fi

    # convert msg
    HTML_DETAIL="";
    echo "$STATUS_DETAIL" | while read msg_line; do
        msg_line="${msg_line//\"/&quot;}";
        msg_line="${msg_line//\\/\\\\}";
        HTML_DETAIL="$HTML_DETAIL&lt;br /&gt;$msg_line";
    done

    sed -i "/<repo name=\"$REPO_NAME\"/d" "$STATUS_FILE";
    sed -i "/<\\/repos>/i <repo name=\"$REPO_NAME\" update=\"$SYNC_TIME\" status=\"$STATUS_MSG\" status_detail=\"$HTML_DETAIL\" url=\"$URL_PATH\" src=\"$SRC_URL\" log=\"$URL_LOG_NAME\" total_size=\"$TOTAL_SIZE\" speed=\"$LAST_SPEED\" />" "$STATUS_FILE";
done < "$SCRIPT_DIR/repos.txt" ;
