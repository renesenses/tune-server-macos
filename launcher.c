/*
 * launcher.c — Thin Mach-O launcher for Tune Server.
 * Finds the real PyInstaller binary in Contents/Resources/ and exec()s it.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <mach-o/dyld.h>

int main(int argc, char *argv[]) {
    char exec_path[4096];
    uint32_t size = sizeof(exec_path);

    if (_NSGetExecutablePath(exec_path, &size) != 0) {
        fprintf(stderr, "Failed to get executable path\n");
        return 1;
    }

    /* Resolve to real path */
    char *real = realpath(exec_path, NULL);
    if (!real) {
        fprintf(stderr, "Failed to resolve path\n");
        return 1;
    }

    /* Go from Contents/MacOS/tune-server to Contents/Resources/tune-server-bin */
    char *dir = dirname(real);  /* Contents/MacOS */
    char resources_rel[4096];
    snprintf(resources_rel, sizeof(resources_rel), "%s/../Resources", dir);
    char *resources = realpath(resources_rel, NULL);
    if (!resources) {
        fprintf(stderr, "Failed to resolve Resources path\n");
        return 1;
    }

    char bin_path[4096];
    snprintf(bin_path, sizeof(bin_path), "%s/tune-server-bin", resources);

    /* Build paths for environment */
    char web_dir[4096];
    snprintf(web_dir, sizeof(web_dir), "%s/web", resources);

    char ffmpeg_path[4096];
    snprintf(ffmpeg_path, sizeof(ffmpeg_path), "%s/ffmpeg", dir);

    char ffprobe_path[4096];
    snprintf(ffprobe_path, sizeof(ffprobe_path), "%s/ffprobe", dir);

    /* Set environment variables */
    setenv("TUNE_WEB_DIR", web_dir, 1);
    setenv("TUNE_FFMPEG_PATH", ffmpeg_path, 1);
    setenv("TUNE_FFPROBE_PATH", ffprobe_path, 1);

    /* Add MacOS dir to PATH for ffmpeg/ffprobe */
    char *old_path = getenv("PATH");
    char new_path[8192];
    snprintf(new_path, sizeof(new_path), "%s:%s", dir, old_path ? old_path : "/usr/bin");
    setenv("PATH", new_path, 1);

    /*
     * Write .env to the sandbox container HOME (writable).
     * The app bundle (/Applications/...) is read-only when installed.
     * Sandboxed HOME = ~/Library/Containers/com.renesenses.tune-server/Data/
     */
    char *home = getenv("HOME");
    if (home) {
        char env_path[4096];
        snprintf(env_path, sizeof(env_path), "%s/.env", home);
        FILE *env_file = fopen(env_path, "w");
        if (env_file) {
            fprintf(env_file, "TUNE_WEB_DIR=%s\n", web_dir);
            fprintf(env_file, "TUNE_FFMPEG_PATH=%s\n", ffmpeg_path);
            fprintf(env_file, "TUNE_FFPROBE_PATH=%s\n", ffprobe_path);
            fclose(env_file);
            fprintf(stderr, "launcher: wrote .env to %s\n", env_path);
        } else {
            fprintf(stderr, "launcher: WARNING: cannot write .env to %s\n", env_path);
        }
        /* chdir to HOME so pydantic-settings finds .env */
        chdir(home);
    } else {
        fprintf(stderr, "launcher: WARNING: HOME not set\n");
        chdir(resources);
    }

    free(real);
    free(resources);

    /* exec the real binary, passing environment explicitly */
    argv[0] = bin_path;
    extern char **environ;
    execve(bin_path, argv, environ);

    /* If we get here, exec failed */
    perror("Failed to launch tune-server-bin");
    return 1;
}
