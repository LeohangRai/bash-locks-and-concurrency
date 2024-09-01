#!usr/bin/env bash

MAX_CONCURRENT_JOBS=1
RETRY_INTERVAL=5

mkdir -p './tmp/locks'
echo '*' >./tmp/.gitignore
SEMAPHORE_FILE='./tmp/locks/semaphore.lock'

# a flag that will be used to track whether the current shell script execution has acquired the lock or not. The 'EXIT' trap gets triggered even when the user interrupts the script execution by hitting 'CTRL+C', which means that the semaphore could be decremented undesirably. By checking the 'LOCK_ACQUIRED' flag, we will determine whether to decrement the semaphore or not based on whether the script actually executed and exited or the user interrupted before the script could even acquire the lock.
LOCK_ACQUIRED=0

# Example:
# Let's say, we set the MAX_CONCURRENT_JOBS to 1 and run the script simultaneously in 4 different terminal sessions.
# We know that initially only 1 script will execute and the others will wait.
# But what if the user hits 'CTRL+C' on either the 3rd or 4th terminal?
# The 'EXIT' trap will be triggered, which will lead to decrement of the semaphore count even though the execution of task '1' has not completed yet.

touch "$SEMAPHORE_FILE"

# function to decrement the semaphore count on script completion (EXIT signal)
function decrement_semaphore() {
    echo "EXIT trap detected..."
    # exit early if lock was not acquired
    if ! [[ $LOCK_ACQUIRED -eq 1 ]]; then
        echo "Lock not acquired, no decrement required"
        exit 0
    fi
    echo "Decrementing the semaphore..."
    exec 200<>"$SEMAPHORE_FILE" # open a read/write '<>' file descriptor on the semaphore file
    flock 200

    # decrement the semaphore count
    CURRENT=$(cat "$SEMAPHORE_FILE")
    if [[ $CURRENT -gt 0 ]]; then
        echo $((CURRENT - 1)) >"$SEMAPHORE_FILE"
    fi

    flock -u 200 # release the lock after decrementing the semaphore count
    exec 200>&-  # close the file descriptor. '>&' is used for redirection. '>&' is normally used to merge the outpout of the left file descriptor to the right one. But, when used with '-', it closes the specified file descriptor.
}

# set the decrement_semaphore function to run on script exit
trap decrement_semaphore EXIT

while true; do
    exec 200<>"$SEMAPHORE_FILE" # open a read/write '<>' file descriptor on the semaphore file
    flock 200

    CURRENT=$(cat "$SEMAPHORE_FILE")

    if [[ -z "$CURRENT" ]]; then
        CURRENT=0
    fi

    if [[ "$CURRENT" -lt "$MAX_CONCURRENT_JOBS" ]]; then
        echo $((CURRENT + 1)) >"$SEMAPHORE_FILE" # increment the semaphore count and proceed (by breaking out of the loop)
        flock -u 200                             # release the lock
        LOCK_ACQUIRED=1                          # set the flag to true (to signal that the semaphore count should be decremented in case the current script gets interrupted by the user)
        exec 200>&-                              # close the file descriptor
        break                                    # break out of the loop
    else
        # release the lock and wait before checking again
        flock -u 200
        exec 200>&-
        echo "Max concurrent scripts running, waiting..."
        sleep $RETRY_INTERVAL
    fi
done

chmod u+x ./script.sh
./script.sh