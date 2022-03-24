#!/usr/bin/env python3
"""
Create an animation using a series of OpenTTD save files and `ffmpeg`.

Save files are taken as positionals, so they can be provided by tools
like `find` or `xargs` to filter and sort through local save files.
"""


from typing import List, NamedTuple, Optional


class Settings(NamedTuple):
    ffmpeg_bin: str
    framerate: float
    scale_output: Optional[str]
    openttd_bin: str
    output_file: str
    save_files: List[str]
    screenshot_naming: str
    screenshot_type: str
    script_file: str


def main() -> int:
    settings = get_settings()
    existent_script = get_file_content(settings.script_file)
    screenshot_files = []

    try:
        for (i, save_file) in enumerate(settings.save_files, 1):
            screenshot_file = settings.screenshot_naming % i
            our_script = make_script(settings, screenshot_file)
            write_file_content(settings.script_file, our_script)
            screenshot_files.append(screenshot_file)
            launch_game(settings.openttd_bin, save_file)

        generate_video(settings, settings.screenshot_naming)

    finally:
        if existent_script:
            write_file_content(settings.script_file, existent_script)
        else:
            remove_file_path(settings.script_file)

        for screenshot_file in screenshot_files:
            remove_file_path(screenshot_file)

    return 0


def get_settings() -> Settings:
    from argparse import ArgumentParser
    from os import X_OK, access
    from os.path import dirname, expanduser, isdir, join
    from shutil import which

    assert type(__doc__) is str, "expecting module-level docstring"
    description, epilog = __doc__.split("\n\n")

    parser = ArgumentParser(description=description, epilog=epilog)

    def is_executable(path: Optional[str]):
        return path and access(path, X_OK)

    ffmpeg_bin_default = next(filter(is_executable, [which("ffmpeg")]), None)
    parser.add_argument(
        "--ffmpeg-bin",
        help=f"ffmpeg binary path; {'detected %(default)s' if ffmpeg_bin_default else 'required'}",
        required=False if ffmpeg_bin_default else True,
        default=ffmpeg_bin_default,
    )

    openttd_bin_default = next(
        filter(
            is_executable,
            [which("openttd"), expanduser("~/Repos/OpenTTD/build/openttd")],
        ),
        None,
    )
    parser.add_argument(
        "--openttd-bin",
        help=f"openttd binary path; {'detected %(default)s' if openttd_bin_default else 'required'}",
        required=False if openttd_bin_default else True,
        default=openttd_bin_default,
    )

    parser.add_argument(
        "--scripts-dir",
        help="openttd scripts path; default is ./scripts directory next to openttd binary",
        required=False,
    )

    screenshots_dir_default = next(
        filter(isdir, [expanduser("~/.local/share/openttd/screenshot")]),
        None,
    )
    parser.add_argument(
        "--screenshots-dir",
        help=f"screenshots directory path; {'detected %(default)s' if screenshots_dir_default else 'required'}",
        required=False if screenshots_dir_default else True,
        default=screenshots_dir_default,
    )

    parser.add_argument(
        "--type",
        choices=[
            # Although you can script `scrollto`, there's no "`zoomto`", so
            # some of these are of limited use in a video... an alternative
            # might be to use `convert` or PIL on the individual screenshots to
            # do zooming and cropping (which would replace `-filter_complex` in
            # `generate_video()` below and probably get a better result).
            "big",
            "giant",
            "heightmap",
            "industry",
            "minimap",
            "normal",
            "topography",
            "viewport",
            "world",
        ],
        help="what kind of 'screenshot' to take of each save file; default %(default)s",
        default="topography",
    )
    parser.add_argument(
        "--output",
        metavar="output.mp4",
        help="video output file to write",
        required=True,
    )
    parser.add_argument(
        "--framerate",
        type=float,
        help="number of screenshots shown per second in video; default %(default)s",
        default=0.5,
    )
    parser.add_argument(
        "--scale-output",
        type=str,
        help="scale output video resolution; can be a preset like ntsc or WxH",
    )
    parser.add_argument("first_save", metavar="first.sav")
    parser.add_argument("next_saves", metavar="next.sav", nargs="+")

    args = parser.parse_args()
    scripts = args.scripts_dir or join(dirname(args.openttd_bin), "scripts")
    screenshot_prefix = get_temp_file_prefix(args.screenshots_dir)
    save_files = [args.first_save, *args.next_saves]
    sequence_specifier = f"%0{len(str(len(save_files)))}d"
    return Settings(
        ffmpeg_bin=args.ffmpeg_bin,
        framerate=args.framerate,
        scale_output=args.scale_output,
        openttd_bin=args.openttd_bin,
        output_file=args.output,
        save_files=save_files,
        screenshot_naming=f"{screenshot_prefix}{sequence_specifier}.png",
        screenshot_type=args.type,
        script_file=join(scripts, "game_start.scr"),
    )


def get_file_content(path: str) -> Optional[str]:
    try:
        with open(path, "r") as input:
            return input.read()
    except FileNotFoundError:
        return None


def get_temp_file_prefix(dir: str) -> str:
    from tempfile import mktemp  # can't use file handle, so not `mkstemp`

    return mktemp(dir=dir, prefix="openttd-animate-") + "-"


def make_script(settings: Settings, screenshot_file: str) -> str:
    from pathlib import Path
    from textwrap import dedent

    script = f"""
        screenshot {settings.screenshot_type} "{Path(screenshot_file).stem}"
        exit
    """
    return dedent(script).strip()


def write_file_content(path: str, content: str):
    with open(path, "w") as output:
        output.write(content)


def launch_game(bin: str, save_file: str):
    from subprocess import run

    run([bin, "-x", "-g", save_file], check=True)


def generate_video(settings: Settings, screenshot_naming: str):
    from subprocess import run

    args = [  # see https://trac.ffmpeg.org/wiki/Slideshow
        *["-r", "1"],  # framerate for the _input_ files
        *["-i", screenshot_naming],
        *["-r", str(settings.framerate)],  # framerate for the _output_ file
        *(
            ["-s", settings.scale_output]
            if settings.scale_output
            else [  # libx264 needs even width/height
                "-vf",
                "crop=trunc(iw/2)*2:trunc(ih/2)*2",
            ]
        ),
        *["-c:v", "libx264"],  # video codec
        "-an",  # no audio on output
        *["-vsync", "cfr"],  # frames duplicated/dropped to achive framerate
        *["-pix_fmt", "yuv420p"],  # better compatibility
        settings.output_file,
    ]
    run([settings.ffmpeg_bin, *args])


def remove_file_path(path: str):
    from os import unlink

    unlink(path)


if __name__ == "__main__":
    exit(main())
