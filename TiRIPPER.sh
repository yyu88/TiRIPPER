#!/bin/bash
#needs gsed, metaflac & ffmpeg (for flac encodes)

#tidalSession="X-Tidal-SessionId: SESSIONKEYHERE"
#token=???
play=0

for var in "$@"
do
albumID="$var"
if [ -z "$albumID" ];then
echo "-->album ID?"
read albumID
fi

if [ ${#albumID} -ge 10 ]; then   
play=1
fi

#superfluous crap probably
#-------------------------
nullCheck=0
while [ "$nullCheck" == 0 ];do
if [ "$play" = 1 ]; then   
html=$(curl -s --http1.1 -H  "$tidalSession" -H "X-Tidal-Token: $token" -H "User-Agent: TIDAL/362 CFNetwork/711.4.6 Darwin/14.0.0" "http://api.tidalhifi.com/v1/playlists/$albumID/items?countryCode=US&limit=100&orderDirection=ASC" | cat )
else
html=$(curl -s --http1.1 -H  "$tidalSession" -H "X-Tidal-Token: $token" -H "User-Agent: TIDAL/362 CFNetwork/711.4.6 Darwin/14.0.0" "http://api.tidalhifi.com/v1/albums/$albumID/tracks?countryCode=US&limit=100&orderDirection=ASC" | cat )
fi
maxItems=$(jq -r '.totalNumberOfItems' <<< "$html")
if [ "$maxItems" == "null" ]; then
echo "$albumID Null error."
echo "-->album ID?"
read albumID
else
nullCheck=1
fi
done
#-------------------------

echo "----Selected Album has $maxItems tracks."

if [ -n "$1" ];then
index=1
avoid=1
avoidInput=1

if [ "$play" = 1 ];then
delm4a=0
else
delm4a=1
fi

else

echo "-->index? (default 1)"
read indexinput
if [ -z "$indexinput" ] || [ "$indexinput" -lt 1 ];then
index=1
avoid=1
avoidInput=1
elif [ "$indexinput" -gt "$maxItems" ];then
echo "Don't be dumb!"
exit
else
avoidInput="$indexinput"
avoid="$indexinput"
index=1
fi

echo "-->convert to flac? 1:yes 0:no (default 1)"
read delinput
if [ -z "$delinput" ] || [ "$delinput" -ne 0 ];then
delm4a=1
else
delm4a=0
fi

fi


for (( i=0; i<maxItems; i++ ))
do
if [ "$play" = 1 ];then
fastCheck=$(jq -r ".items[$i].item.audioQuality" <<< "$html")
else
fastCheck=$(jq -r ".items[$i].audioQuality" <<< "$html")
fi
if [ "$fastCheck" != "LOSSLESS" ] && [ "$fastCheck" != "HI_RES" ]; then
echo "Track $((i+1)) not LOSSLESS! Type anything once to stop ripping and continue output."
echo "$fastCheck"
if [ -z "$filler" ]; then
read filler
else
stop=1
fi
fi
done


if [ "$stop" = 1 ]; then
exit
fi

if [ "$play" = 1 ];then
while read -r name
do
trackName+=("$name");
done < <(jq -r '.items[].item.title' <<< "$html")
else
while read -r name
do
trackName+=("$name");
done < <(jq -r '.items[].title' <<< "$html")
fi

if [ "$play" = 1 ];then
while read -r name
do
trackNumber+=("$name");
done < <(jq -r '.items[].item.trackNumber' <<< "$html")
else
while read -r name
do
trackNumber+=("$name");
done < <(jq -r '.items[].trackNumber' <<< "$html")
fi

###split singles in different folder
if [ "$play" = 1 ];then
albumName="$albumID"
else
albumName=$(gsed -e 's@/@,@g' <<< $(jq -r '.items[0].album.title' <<< "$html"))
fi


#VA CHECK
#--------
if [ "$play" = 0 ];then


if [ "$maxItems" -ge 3 ];then
artistNameA=$(jq -r '.items[1].artist.name' <<< "$html")
artistNameB=$(jq -r '.items[2].artist.name' <<< "$html")
artistNameC=$(jq -r '.items[0].artist.name' <<< "$html")
if [ "$artistNameA" = "$artistNameB" ] && [ "$artistNameB" = "$artistNameC" ] && [ "$artistNameA" = "$artistNameC" ];then
artistName=$(jq -r '.items[1].artist.name' <<< "$html")
else
artistName="VA"
fi
else
artistName=$(jq -r '.items[0].artist.name' <<< "$html")
fi

fi
#--------

if [ "$play" = 0 ];then
yearF=$(jq -r ".items[0].streamStartDate" <<< "$html" | cut -c1-4)
fi

if [ "$delm4a" = 1 ];then
mkdir "Playlist - $albumName [FLAC] web"
else
mkdir "$artistName - $albumName ($yearF) [ALAC] web"
fi
cd "$_"

#inefficient way of clearing probably but worth the hassle
if ls RIPPERTEMP.txt 1> /dev/null 2>&1; then
chmod 777 RIPPERTEMP.txt
rm RIPPERTEMP.txt
fi


if [ "$play" = 1 ];then
jq '.items[].item.id' <<< "$html" >> RIPPERTEMP.txt
else
jq '.items[].id' <<< "$html" >> RIPPERTEMP.txt
fi

filename="RIPPERTEMP.txt"

if ls cover.jpg 1> /dev/null 2>&1; then
echo "Already Cover Exists."
else

if [ "$play" = 0 ];then
coverLocation=$(jq -r '.item[0].album.cover' <<< "$html")
imageURL="https://resources.tidal.com/images/${coverLocation//-//}/1280x1280.jpg"
wget -O cover.jpg "$imageURL"
fi
fi

while read -r line
do
skip=0

if [ $avoid = $index ]; then

if [ $index -lt 10 ]; then
findex="0${index}"
else
findex="$index"
fi
dindex=$((index-1))

name="$line"
newfix=$(gsed -e 's@/@,@g' <<< "${trackName[dindex]}")



if ls "${findex} - $newfix.m4a" 1> /dev/null 2>&1;then
echo "Already Exists."
skip=1
elif ls "${findex} - $newfix.flac" 1> /dev/null 2>&1;then
echo "Already Exists."
skip=1
else
wget --tries=2 -O "${findex} - $newfix.m4a" "$(curl -s -H  "$tidalSession" -H "X-Tidal-Token: $token" -H "User-Agent: TIDAL/362 CFNetwork/711.4.6 Darwin/14.0.0" "http://api.tidalhifi.com/v1/tracks/$name/streamurl?countryCode=US&soundQuality=LOSSLESS" | jq -r ."url")"

if [ "$delm4a" = 1 ] && [ "$skip" = 0 ];then
if [ "$play" = 1 ];then
year=$(jq -r ".items[$dindex].item.streamStartDate" <<< "$html" | cut -c1-4)
artistName=$(jq -r ".items[$dindex].item.artist.name" <<< "$html")
albumNameN=$(jq -r ".items[$dindex].item.album.title" <<< "$html")
ffmpeg -y -i "${findex} - ${trackName[dindex]}.m4a" -metadata title="${trackName[dindex]}" -metadata album="$albumNameN" -metadata track="${trackNumber[dindex]}" -metadata artist="$artistName" -metadata year="$year" -f flac "${findex} - ${trackName[dindex]}.flac" < /dev/null
rm "${findex} - ${trackName[dindex]}.m4a"
else
year=$(jq -r ".items[$dindex].streamStartDate" <<< "$html" | cut -c1-4)
artistName=$(jq -r ".items[$dindex].artist.name" <<< "$html")
ffmpeg -y -i "${findex} - ${trackName[dindex]}.m4a" -metadata title="${trackName[dindex]}" -metadata album="$albumName" -metadata track="${trackNumber[dindex]}" -metadata artist="$artistName" -metadata year="$year" -f flac "${findex} - ${trackName[dindex]}.flac" < /dev/null
rm "${findex} - ${trackName[dindex]}.m4a"
fi


fi
avoid=$((avoid+1))
index=$((index+1))

fi

else
index=$((index+1))
fi

done < "$filename"

if [ "$delm4a" = 1 ];then
echo 'Adding gain..'
#metaflac --add-replay-gain *.flac
fi

chmod 777 RIPPERTEMP.txt
rm RIPPERTEMP.txt

itemCount=$(($(\ls -afq | wc -l)-2))
if ls ".DS_Store" 1> /dev/null 2>&1;then
echo "----.DS_Store garbage found in folder."
maxItems=$((maxItems+1))
fi
if [ "$itemCount" = $((maxItems-avoidInput+2)) ]; then
echo "Index start was at $avoidInput."
echo "$itemCount files found."
echo "100% SUCCESSFULLY RIPPED."
else
echo "early termination or error -- check files"
fi

trackName=()
trackNumber=()
cd ..
done
exit
