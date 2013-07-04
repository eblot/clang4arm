#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <unistd.h>
#include <sys/param.h>

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

	array[0] = python;

	static char wpath[MAXPATHLEN];
	const char * split = strrchr(argv[0], '/');
	if ( split )
	{
		int pos = split-argv[0]+1;
		strncpy(script_path, argv[0], pos);
		strcpy(script_path+pos, script);
		array[1] = script_path;
	}
	else
	{
		array[1] = NULL;

		// the wrapper has been called from the PATH, not with a full path
		// name, try to locate the Python wrapper within the same path...
		// this is a heureustic way to locate the wrapper, as there is proper
		// way to get the actual executable wrapper path on Un*x (vs. Linux...)
		char * path = strdup(getenv("PATH"));
		char * tpath = path;
		char * token;

		while ( (token = strsep(&path, ":")) )
		{
            snprintf(wpath, sizeof(wpath), "%s/%s", token, script);
            printf("%s -> %s\n", token, wpath);

            if ( ! access(wpath, R_OK) )
            {
            	array[1] = wpath;
            	break;
            }
		}
		free(tpath);
		if ( ! array[1] )
		{
			fprintf(stderr, "Cannot locate wrapper: %s\n", argv[0]);
			return -1;
		}
	}

	for (unsigned int pos=0; pos<argc; pos++)
	{
		array[2+pos] = argv[pos+1];
	}
	array[argc+1] = '\0';

	rc = execvp(python, array);

	// execvp should not return, except if it fails to replace the current
	// process with the forked one
	perror("Cannot fork Python VM");

	free(array);

	return rc;
}
