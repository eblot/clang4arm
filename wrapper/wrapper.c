#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

static char python[]="python2.7";
static char script[]="wrapper.py";
char script_path[512];

int main(int argc, char ** argv)
{
	int rc;

	char ** array = malloc(sizeof(char *)*(argc+4));
	if ( ! array )
	{
		return -1;
	}

	const char * split = strrchr(argv[0], '/');
	if ( ! split )
	{
		return -1;
	}

	int pos = split-argv[0]+1;
	strncpy(script_path, argv[0], pos);
	strcpy(script_path+pos, script);
	array[0] = python;
	array[1] = script_path;
	for (int pos=0; pos<argc; pos++)
	{
		array[2+pos] = argv[pos+1];
	}
	array[argc+1] = '\0';

	rc = execvp(python, array);

	free(array);

	return rc;
}
