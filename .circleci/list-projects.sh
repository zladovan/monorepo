DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

for PROJECT in $(cat ${DIR}/projects.txt); do 
	echo ${PROJECT} 
done
