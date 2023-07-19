#!/bin/bash

#-------------------------------------------------------------------------
#help function
display_help() {
  echo " Usage: ./script.sh [directory_path] [extentions] [options]"
  echo " the extentions must be separated by ',' like 'txt,jpg'"
  echo " options : "
  echo " -f : to apply filter by size , permissions, or last modified date"
  echo " -s : to add a generate a summary report that displays total file count, total size, and other relevant statistics."
  echo " This script searches for files with a specific extension in the given directory and its subdirectories,"
  echo " generates a comprehensive report with file details, groups the files by owner, and saves the report in 'file_analysis.txt'."
  exit 0
}

# show help section
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  display_help
  exit 0
fi

# check if the directory is valid
if [ ! -d "$1" ]; then
  echo " Invalid directory path"
  echo " to show help massage use -h or --help" 
  exit 0
fi

# check for extentions
re="^[a-zA-Z0-9,]*$"
if [[ -z "$2" || "$2" == "-s" || "$2" == "-f" || ! "$2" =~ $re ]]; then
  echo " Invalid extentions"
  echo " to show help massage use -h or --help" 
  exit 0 
fi

# check number of arguments and options.
if [[ $# -gt 4 ]]; then
  echo " Invalid arguments"
  echo " to show help massage use -h or --help" 
  exit 0
fi

if [ $# -eq 3 ]; then
  if [[ "$3" != "-s" && "$3" != "-f" ]]; then
    echo " Invalid arguments"
    echo " to show help massage use -h or --help" 
    exit 0
  fi
fi

if [ $# -eq 4 ]; then
  if [[ "$3" != "-s" && "$3" != "-f" ]] || [[ "$4" != "-s" && "$4" != "-f" ]]; then
    echo " Invalid arguments"
    echo " to show help massage use -h or --help" 
    exit 0
  fi
fi

# check if the file_analysis file is exist and delete it
if [ -f "$1/file_analysis.txt" ]; then
  rm file_analysis.txt
fi
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Set the directory path.
dir_path="$1"
#sperate extentions and store them in array
extentions=$(echo "$2" | tr ',' '\n')

#get all files
files=$(find $dir_path -type f)

#split a files string to a array of paths
files=($(echo $files | tr ' ' "\n"))

#filter the files by extentions
filtered_files=()
for file in "${files[@]}"; do
  file_ext="${file##*.}"
  if [[ ${extentions[@]} =~ $file_ext ]]; then
    filtered_files+=("$file")
  fi
done
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#applying filter option and validate inputs
if [[ "$3" == "-f" || "$4" == "-f" ]]; then
re='^[0-9]+$'

  #validate size
  echo "enter the min size of files in bytes"
  while true ;do
    read minSize
    if [[ $minSize =~ $re ]] ;then
      break 
    fi
  echo "please enter valid number"
  done

  echo "enter the max size of files in bytes"
  while true ;do
    read maxSize
    if [[ $maxSize =~ $re && ! $maxSize -lt $minSize ]]; then
    break
    fi
  echo "please enter valid number"
  done

#validate dates
  re='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  echo "enter the min date of modified in format 'yyyy-mm-dd'"
  while true ;do
    read minDate
    if [[ $minDate =~ $re ]] ;then
    minDate=$(echo $minDate | tr -d "-")
    break
    fi
  echo "please enter valid date"
  done

  echo "enter the max date of modified in format 'yyyy-mm-dd'"
  while true ;do
      read maxDate
    if [[ $maxDate =~ $re ]] ;then
    maxDate=$(echo $maxDate | tr -d "-")
      if [[ ! $maxDate -lt $minDate ]];then
      break
      fi
    fi
  echo "please enter valid date"
  done
  
  echo "enter the permissions seperated by ',' like 'rw-r--r--,drwxr-xr-x'"
  re="^[A-Za-z,-]+$"
  while true ;do
      read pers
    if [[ $pers =~ $re ]] ;then
    pers=$(echo "$pers" | tr ',' '\n')
    break
    fi
  echo "please enter valid permissions"
  done  
  
fi
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------

declare -A file_details
declare -A file_by_owner
declare -A total_size_by_owner
declare -A temp_total_size_by_owner
save_file_details(){
    #total size by owner
    let total=total_size_by_owner[$owner];
    total_size_by_owner[$owner]=$((total+size))
    temp_total_size_by_owner[$owner]=$((total+size))
    
    #store file details
    file_details[$file]="file name : $file_name | file size : $size bytes | file permissions : $permissions | last time modified : $modified_timestamp \n"

    #store files by owner
    file_by_owner[$owner]+="$file,"
}

#save files details
temp_files=()
for file in "${filtered_files[@]}"; do
    file_name=$(basename -- "$file")
    owner=$(stat -c %U "$file")
    let size=$(du -b "$file" | cut -f1)
    permissions=$(stat -c %A "$file")
    modified_timestamp=$(stat -c %y "$file")
    modified_date=$(stat -c %y "$file" | cut -d' ' -f1 | tr -d "-")
    
    if [[ "$3" == "-f" || "$4" == "-f" ]]; then
      if (( $size <= $maxSize )) && (( $size >= $minSize ));then
        if (( $modified_date <= $maxDate )) && (( $modified_date >= $minDate ));then
          if [[ ${pers[@]} =~ $permissions ]]; then
            temp_files+=("$file")
            save_file_details
          fi
        fi
       fi
     else
      save_file_details
     fi
done

    if [[ "$3" == "-f" || "$4" == "-f" ]]; then
      filtered_files=("${temp_files[@]}")
    fi

#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#sort owners by size
number_of_owners="${#file_by_owner[@]}"
sorted_owners=()
while [ $number_of_owners -gt 0 ]; do
  max_size=-1
  for owner in "${!temp_total_size_by_owner[@]}";do
    if [[ ${temp_total_size_by_owner[$owner]} -gt $max_size ]]; then
      max_size=${temp_total_size_by_owner[$owner]}
      max_size_owner=${owner}
    fi  
  done

  sorted_owners+=($max_size_owner)
  unset temp_total_size_by_owner[$max_size_owner]
  ((number_of_owners--))
done
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#generate a summary report that displays total file count, total size, and other relevant statistics.
if [[ "$3" == "-s" || "$4" == "-s" ]]; then
  echo "summary of files report" >> file_analysis.txt
  total_file_count="${#file_details[@]}"
  number_of_owners="${#sorted_owners[@]}"
  total_size=0;
  for owner in "${sorted_owners[@]}" ;do
    total_size=$((total_size_by_owner[$owner]+total_size))
  done
  echo "total numbner of files : $total_file_count" >> file_analysis.txt
  echo "total numbner of owners : $number_of_owners" >> file_analysis.txt
  echo "total file size : $total_size bytes" >> file_analysis.txt
  echo -e "---------------------------------------- \n" >> file_analysis.txt
fi
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#store data in report
for owner in "${sorted_owners[@]}" ;do
   echo -e "owner name : $owner , total files size : ${total_size_by_owner[$owner]} bytes \n " >> file_analysis.txt
   #split owner files to array
   owner_files=${file_by_owner[$owner]}
   IFS=',' read -ra files <<< "$owner_files"
   for file in "${files[@]}" ;do
   echo -e ${file_details[$file]} >> file_analysis.txt
   done
   echo "----------------------------------------" >> file_analysis.txt
done
#-------------------------------------------------------------------------
echo "file report is generated"