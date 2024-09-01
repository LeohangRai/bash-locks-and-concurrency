echo "Script execution started"
progress=10
while [ $progress -lt 101 ]; do
    echo -n -e "\033[77DRunning script...$progress%"
    # simulate error status
    # if [ $progress -gt 50 ]; then
    #     echo -e "\nExiting..."
    #     exit 1
    # fi
    progress=$(($progress + 10))
    sleep 1
done
echo -e "\nScript execution completed"
