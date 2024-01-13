#!/bin/bash
################################################################################
##    Bash script for file or directory compression                           ##
################################################################################



## Configuration variables
################################################################################
##    Setting paths and names
################################################################################

##  $srcName - Source, file or directory to compress.
## Источник, файл или каталог для сжатия.

srcName="test-file"


##  $srcDir - Directory where the source resides.
## Каталог, в котором находится источник

srcDir="/tmp/"


##  $runDir - Runtime directory. Lock and log files reside here.
## каталог времени выполнения.Здесь находятся файлы блокировки и журнала.

runDir="/tmp/run/"


##  $outDir - Directory where the archive will be placed.
## Каталог, где будет размещен архив.

outDir="/tmp/out/"


##  $archDir - Directory where the previous archives will be placed.
## Каталог, где будут размещены предыдущие архивы.

archDir="/tmp/vault/"


##  $archName - Archive file name.
## Архивное имя файла
##    [ example: "archive_$(date +"[%Y.%m.%d - %H:%M:%S]")" ]

archName="archive_$(date +"%Y.%m.%d-%H:%M:%S")"


################################################################################
##    Setting Archives                 
################################################################################

##  $compressor - Compressor and it's params.
##    [ default: "xz -T 4 -9 -c" ]

compressor="gzip -9 -c"


##  $archExt - Archive extension, depending on $compressor setting.
##    Расширение архива, в зависимости от настройки компрессора $.
##    [ default: ".tar.xz" ]

archExt=".tar.gz"

################################################################################
##    Setting aging archives
################################################################################

##  oldArchDaysBack - How much time (in days) into the past, search must look
##    for old archive files inside the vault ($archDir) for deleting the oldest.
##    [ default: 30 ] - One month.
##    @WARNING! If you set $maxOldArch to say 10 and you run archivation process
##      say every 24 hours, but your $oldArchDaysBack is set to 7, script will
##      not be able to account for 3 oldest archive files, so your vault can
##      grow more than 10!

oldArchDaysBack=2


##  maxOldArch - How much old archive files must be kept inside the vault.
##    [ default: 30 ]
##    @WARNING! Do not set higher than $oldArchDaysBack if you run this script
##      daily!

maxOldArch=1


################################################################################
##    Setting Logging                 
################################################################################

##  $logName - Log file name.

logName=$archName

## $stdType - Sets output to console and or log file.
## [ default: "cl" ] { "cl" = console & log, "l" = log only }

stdType="cl"


################################################################################
##    Setting Debugging
################################################################################

## $debug - Enable debugging or not.
## [ default: true ]

debug=true


################################################################################
##    Setting Lock Files                 
################################################################################

##  $lockCheck - Check for lock file or not.
##    If you have condition(s) in which creation of an archive is not
##    recommended or fatal (e.g. while creating snapshot, directory must not
##    be tempered with in any way) and the process which is running prior to
##    archivation (rsnapshot, rsync, rdiff etc.), can create a lock file,
##    you must switch this check ON and fill out a name for a lock file,
##    to prevent integrity violation.
##    [ default: true ]

lockCheck=true


##  $lockName - Lock file name.

lockName=$archName


##  $lockSleep - How much time to wait until next try (in seconds).
##    [ default: 600 ] - 10 minutes.

lockSleep=600


##  $lockWait - How many tries before script stop.
##    [ default: 12 ] - Retry for 2 hours if $lockSleep = 600

lockWait=10


################################################################################
##    Setting Sending Mail                 
################################################################################

##  $mailSendSucc - Enable mail sending on success.

mailSendSucc=false


##  $mailSendFail - Enable mail sending on fail.

mailSendFail=false


##  $mailFileName - Mail file name.

mailFileName=$archName


##  $mailTo - To which e-mail messages must be sent.

mailTo="your@email.address"


##  $mailSubject - Subject of the message.

mailSubjectSucc="$0 says: Process has finished successfuly!"
mailSubjectFail="$0 says: Warning! Process has failed!"


################################################################################
##    Setting Appearance                  
################################################################################

## $timeStamp - Timestamp format.
## [ default: "[%Y.%m.%d - %H:%M:%S]" ]

timeStamp="[%Y.%m.%d - %T]"


##  $txtFormat - Allow text formating (bold and colored text).
##    [ default: true ]

txtFormat=true


## ---------------- ##
## Helper functions ##
## ---------------- ##

## Prints messages.
## [ example: msg "Archive file name is: %s\n" "$arcname" ]
msg() { 
    [[ $stdType == "cl" ]] && printf "$@" | tee /dev/fd/3 || printf "$@" ; 
}

## Prints timestamp.
## [ example: "$(tStamp "[%Y.%m.%d - %H:%M:%S]")" ]
## [ fallback: "${timeStamp}" ]
tStamp() {
  if [[ -n ${1} ]] && [[ ! -n ${2} ]] ; then
    date +"${1}"
  elif [[ -n ${1} ]] && [[ -n ${2} ]] ; then
    date -d "${2}" +"${1}"
  else
    date +"${timeStamp}"
  fi
}

##  ifDebug() - Checks if debuging is enabled.
## Checks debug status.
ifDebug() { [[ $debug == true ]] ; }

##  tf() - Formats text.
## Text formating.
tf() {
  if [[ $txtFormat == true ]] ; then
    res=""
    for ((i=2; i<=$#; i++)) ; do
      case "${!i}" in
        "bold" ) res="$res\e[1m" ;;
        "underline" ) res="$res\e[4m" ;;
        "reverse" ) res="$res\e[7m" ;;
        "red" ) res="$res\e[91m" ;;
        "green" ) res="$res\e[92m" ;;
        "yellow" ) res="$res\e[93m" ;;
      esac
    done
    echo -e "$res$1\e[0m"
  else
    echo "$1"
  fi
}

##  succ() - Process success output.
## Outputs process success.
succ() { 
    msg "%s %s!\n\n" "$(tStamp)" "$(tf "SUCCESS" "bold" "green")" \
    ; sendMail ; exit 0 ; 
}

##  fail() - Process fail output.
## Outputs process fail.
fail() { 
    msg "%s %s at %s!\n\n" "$(tStamp)" "$(tf "FAIL" "bold" "red")" \
    "$(tf "$1" "bold" "underline" "yellow")" ; sendMail "$1" ; exit 1 ; 
}

##  sendMail() - Sends e-mails.
## Sends e-mail.
sendMail() {
  if [[ ! -n $1 ]] && [[ $mailSendSucc == true ]] ; then
    echo "Process finished, no errors found!" > $mailFile
    mail -s "$mailSubjectSucc" $mailTo < $mailFile
  fi
  if [[ -n $1 ]] && [[ $mailSendFail == true ]] ; then
    echo "Process has failed at step: $1" > $mailFile
    mail -s "$mailSubjectFail" $mailTo < $mailFile
  fi
}

##  checkLock() - Checks for lock file.
## Checks lock status.
ifLock() { [[ $lockCheck == true ]] ; }

##  checkLock() - Checks for lock file.
## Checks for lock file.
checkLock() {
  [[ -f ${lockFile} ]] && ifDebug && msg \
   " -> Lock file %s, waiting iterations are set to: %s\n" \
    "$(tf "is in place" "bold")" "$(tf "$lockWait" "bold")"
  for ((i=1; i<=lockWait; i++)) ; do
    if [[ -f ${lockFile} ]] ; then
      ifDebug && msg " -> waiting for %s (%s)\n" \
       "$(tf "$(secToTime "$lockSleep")" "bold")" \
        "$(tf "$i" "bold" "yellow")" ; sleep $lockSleep
    else
      i=1000
    fi
    if [[ $i == "$lockWait" ]] ; then
      msg " -> Lock file %s, exiting...\n" "$(tf "still in place" "bold")"
      fail "lock file check"
    fi
  done
}

##  secToTime() - Turns seconds into readable time (e.g. 3h 45m 21s).
## Seconds to readable time.
secToTime() {
  timeInSec=$1
  if [[ $timeInSec -ge 0 ]] && [[ $timeInSec -le 59 ]]; then
    echo "${timeInSec}s"
  elif [[ $timeInSec -ge 60 ]] && [[ $timeInSec -le 3599 ]]; then
    m=$(( timeInSec / 60 ))
    s=$(( timeInSec % 60 ))
    echo "${m}m ${s}s"
  elif [[ $timeInSec -ge 3600 ]] && [[ $timeInSec -le 86399 ]]; then
    h=$(( timeInSec / 3600 ))
    m=$(( (timeInSec % 3600) / 60 ))
    s=$(( (timeInSec % 3600) % 60 ))
    echo "${h}h ${m}m ${s}s"
  fi
}

## checkConf() - Validates configuration.
## Checks configuration.
checkConf() {

    ## Check file/directory permissions.
    checkPerm() {
        if [[ ! -n ${2} ]] ; then
            [[ -r ${1} ]] && [[ -w ${1} ]] && echo 1 || echo 0 ;
        else
            case "$2" in
            "f" ) [[ -f ${1} ]] && [[ -r ${1} ]] && [[ -w ${1} ]] && \
                echo 1 || echo 0 ;;
            "d" ) [[ -d ${1} ]] && [[ -r ${1} ]] && [[ -w ${1} ]] && \
                echo 1 || echo 0 ;;
            "fd" ) [[ -d ${1} ]] || [[ -f ${1} ]] && [[ -r ${1} ]] && \
                [[ -w ${1} ]] && echo 1 || echo 0 ;;
            esac
        fi
    }

    ## Output file/directory status.
    status() { 
        [[ $1 == 1 ]] && tf "OK" "bold" "green" || \
        tf "NOT OK" "bold" "red" ; 
    }

    ## Check source.
    pass=$(( pass + $(checkPerm "$src" "fd") ))
    ifDebug && msg " -> Source\t\t%s\tis set to: %s\n" \
    "$(status "$(checkPerm "$src" "fd")")" "$(tf $src "bold")"

    ## Check runtime directory.
    pass=$(( pass + $(checkPerm "$runDir" "d") ))
    ifDebug && msg " -> Runtime directory   %s\tis set to: %s\n" \
    "$(status "$(checkPerm "$runDir" "d")")" "$(tf $runDir "bold")"

    ## Check output directory.
    pass=$(( pass + $(checkPerm "$outDir" "d") ))
    ifDebug && msg " -> Output  directory   %s\tis set to: %s\n" \
    "$(status "$(checkPerm "$outDir" "d")")" "$(tf $outDir "bold")"

    ## Check archive directory.
    pass=$(( pass + $(checkPerm "$archDir" "d") ))
    ifDebug && msg " -> Archive directory   %s\tis set to: %s\n" \
    "$(status "$(checkPerm "$archDir" "d")")" "$(tf $archDir "bold")"

    ## Display rest of the config.
    ifDebug && msg " -> Archive\t\t\tis set to: %s\n" \
    "$(tf $archiveFN "bold")"
    ifDebug && msg " -> Log file\t\t\tis set to: %s\n" \
    "$(tf $logName "bold")"
    ifDebug && ifLock && msg " -> Lock file\t\t\tis set to: %s\n" \
    "$(tf $lockName "bold")"
    ifDebug && msg " -> Timestamp\t\t\tis set to: %s\n" \
    "$(tf "$timeStamp" "bold")"
    ifDebug && msg " -> Compressor\t\t\tis set to: %s\n" \
    "$(tf "$compressor" "bold")"

    ## Validate config
    if [[ $pass == 4 ]] ; then
        ifDebug && msg " -> Configuration is    %s\n" "$(status 1)"
    else
        msg " -> Configuration is    %s, exiting...\n" "$(status 0)"
        fail "configuration check"
    fi
}

##  checkForOldArch() - Checks old archive files.
## Checks if the old archive exists, if it does, deletes it.
checkForOldArch() {
  if [[ -f ${archive} ]] ; then

    oldArchCount() {
      res=$(printf "%s" "$(ls -afq $archDir | wc -l)")
      echo $(( res - 2 ))
    }
    oldestArch() {
      find $archDir -type f -mtime -$oldArchDaysBack -print0 \
       | xargs -0 ls -tr | head -n 1
    }

    ## Move previous archive to the vault and rename it.
    ifDebug && msg \
     " -> Previous archive file %s, created on %s in %s, moving...\n" \
      "$(tf "exists" "bold" "yellow")" \
       "$(tf "$(date -r $archive +"%Y.%m.%d")" "bold")" \
        "$(tf "$(date -r $archive +"%R")" "bold")"
    prevArch="$archDir/$archName$(date -r $archive +"_%Y%m%d-%H%M%S")$archExt"
    mv -f "$archive" "$prevArch" || fail "moving archive to the vault"

    ## Check if previous archive were moved to the vault.
    if [[ -f ${prevArch} ]] && [[ ! -f ${archive} ]] ; then
      ifDebug && msg \
       " -> Previous archive %s to the vault as: %s, proceeding...\n" \
        "$(tf "moved" "bold" "green")" "$(tf "$prevArch" "bold")"
      execute=$(( execute + 1 ))
    else
      msg " -> %s %s previous archive to the vault, exiting...\n" \
       "$(tf "WARNING!" "bold" "yellow")" "$(tf "Can't move" "bold")"
      fail "moving archive to the vault"
    fi

    ## Count old archive files inside the vault and delete the oldest.
    oldArchCount=$(oldArchCount)
    if [[ $oldArchCount -gt $maxOldArch ]] ; then
      ifDebug && msg " -> Number of old archives inside the vault is: %s\n" \
       "$(tf "$(oldArchCount)" "bold")"
      for ((i=oldArchCount; i>maxOldArch; i--)) ; do
        oldestArch=$(oldestArch)
        rm -f "$oldestArch" || fail "delete oldest archive"
        if [[ ! -f ${oldestArch} ]] ; then
          ifDebug && msg " -> Oldest file (%s) %s, proceeding...\n" \
           "$(tf "$oldestArch" "bold")" "$(tf "was deleted" "bold" "yellow")"
        else
          msg " -> %s %s the oldest archive (%s), exiting...\n" \
           "$(tf "WARNING!" "bold" "yellow")" "$(tf "Can't delete" "bold")" \
            "$(tf "$oldestArch" "bold")" ; fail "delete oldest archive"
        fi
      done
    fi

    ## Check if old archives were indeed deleted.
    ifDebug && msg " -> Number of old archives inside the vault is: %s\n" \
     "$(tf "$(oldArchCount)" "bold")"
    oldArchCount=$(oldArchCount)
    if [[ $oldArchCount -gt 10 ]] ; then
      msg " -> %s %s the oldest archive(s), exiting...\n" \
       "$(tf "WARNING!" "bold" "yellow")" "$(tf "Can't delete" "bold")"
      fail "delete oldest archive(s)"
    else
      execute=$(( execute + 1 ))
    fi

  else
    ifDebug && msg " -> Old archive %s, proceeding...\n" \
     "$(tf "does not exist" "bold" "green")" ; execute=2
  fi
}

## Begins compression process.
compress() {
  if [[ $execute == 2 ]] ; then
    ifDebug && msg " -> Flag %s set, executing...\n" "$(tf "is" "bold" "green")"
    execComp

    execTime=$(round "$execTime" 0)
    execTime=$(secToTime "$execTime")

    ## Check if archive file created.
    if [[ -f ${archive} ]] ; then
      msg " -> Archive %s created in %s!\n" "$(tf $archive "bold")" \
       "$(tf "$execTime" "bold")" ; compInf $src $archive ; succ
    else
      msg " -> %s Archive file was %s created, exiting...\n" \
       "$(tf "WARNING!" "bold" "yellow")" "$(tf "not" "bold" "red")"
      fail "archive file creation"
    fi
  else
    msg " -> Flag %s set, exiting...\n" "$(tf "is not" "bold" "red")"
    fail "execution flag check"
  fi
}

##  execComp() - Executes compression and assigns execution time to $execTime.
## Executes compression.
execComp() {
  ## Go to source directory.
  cd $srcDir || fail "cd to source directory"
  if [[ ${PWD} != "$srcDir" ]] ; then
    msg " -> %s Can't cd to source directory, exiting...\n%s" \
     "$(tf "WARNING!" "bold" "yellow")" ; fail "cd to source directory"
  fi
  
  execTime=$( { time tar cf - $srcName | $compressor - > $archive ; } 2>&1 )
}

#  compInf() - Outputs compression info.
##    [ example: compInf $src $archive ]
## Outputs compression info.
compInf() {
  msg "\t-> Source size: %s (%s bytes)\n" \
   "$(tf "$(size "$1" "h")" "bold")" "$(tf "$(size "$1" "b")" "bold")"
  msg "\t-> Archive size: %s (%s bytes)\n" \
   "$(tf "$(size "$2" "h")" "bold")" "$(tf "$(size "$2" "b")" "bold")"
  msg "\t-> Compression ratio: %s\n" \
   "$(tf "$(compRatio "$(size "$1" "b")" "$(size "$2" "b")")" "bold")"
}

## Rounds floating numbers.
round() { 
  printf %."$2"f "$(echo "(((10^$2)*$1)+0.5)/(10^$2)" | bc)" ; 
}

##  size() - Gets object size values.
##    @Takes two parameters, object and presentation format
##      (h - human readable, b - bytes)!
##    [ example: "$(size "$src" "b")" ]
## Gets object size values.
size() {
  [[ $2 == "b" ]] && du -bs "$1" | awk '{ print $1 }'
  [[ $2 == "h" ]] && du -hs "$1" | awk '{ print $1 }'
}

##  compRatio() - Gets compression ratio.
##    @Takes two parameters, source and archive!
##    [ example: "$(compRatio "$src" "$archive")" ]
## Gets compression ratio.
compRatio() { 
  printf "%.*f" 2 "$(let res="$1/$2"; printf "%s" "$res")" ; 
}


# Preparing step

# Для создания вывода времени для команды time в виде 0.000
TIMEFORMAT="%E"

runDir=${runDir%/} ; srcDir=${srcDir%/} ; srcName=${srcName%/} ## Deslashify.
outDir=${outDir%/} ; archDir=${archDir%/} ## Deslashify.

src="$srcDir/$srcName" ## Full path to source.
archiveFN="$archName$archExt" ## Archive file name and extension.
archive="$outDir/$archiveFN" ## Full path to archive.
logFile="$runDir/$logName.log" ## Full path to log file.
logFileF="$runDir/$logName.f.log" ## Full path to log file.
lockFile="$runDir/$lockName.lock" ## Full path to lock file.
mailFile="$runDir/$mailFileName.mail" ## Full path to mail file.
execute=0 ## Allow execution.
execTime="" ## Compression execution time.

# Initial setup step

exec 3>&1 1>>$logFile 2>&1 ## Modifies std output.

## Running step
  
msg "%s Initializing...\n" "$(tStamp)"
checkConf
ifLock && checkLock
checkForOldArch
compress