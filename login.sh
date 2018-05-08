#need your token too
echo "-->email(before the @)?"
read email
echo "-->email server(after the @)?"
read server
echo "-->password?"
read pw
curl --silent -H "X-Tidal-Token: _DSTon1kC8pABnTw" -H "User-Agent: TIDAL/362 CFNetwork/711.4.6 Darwin/14.0.0" --data "username=$email%40$server&password=$pw&clientVersion=1.12.1&clientUniqueKey=" api.tidalhifi.com/v1/login/username | jq -r ".sessionId"
