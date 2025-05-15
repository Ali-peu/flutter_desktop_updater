import "dart:convert";
import "dart:io";

import "package:desktop_updater/desktop_updater.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as path;

Future<ItemModel?> versionCheckFunction({
  required String appArchiveUrl,
}) async {
  final executablePath = Platform.resolvedExecutable;

  final directoryPath = executablePath.substring(
    0,
    executablePath.lastIndexOf(Platform.pathSeparator),
  );

  var dir = Directory(directoryPath);

  if (Platform.isMacOS) {
    dir = dir.parent;
  }

  if (await dir.exists()) {
    final tempDir = await Directory.systemTemp.createTemp("desktop_updater");

    final client = http.Client();

    print("Using url: $appArchiveUrl");

    final appArchive = http.Request("GET", Uri.parse(appArchiveUrl));
    final appArchiveResponse = await client.send(appArchive);

    final outputFile =
        File("${tempDir.path}${Platform.pathSeparator}app-archive.json");

    final sink = outputFile.openWrite();
    await appArchiveResponse.stream.pipe(sink);
    await sink.close();

    print("app archive file downloaded to ${outputFile.path}");

    if (!outputFile.existsSync()) {
      throw Exception("Desktop Updater: App archive does not exist");
    }

    final appArchiveString = await outputFile.readAsString();

    final appArchiveDecoded = AppArchiveModel.fromJson(
      jsonDecode(appArchiveString),
    );

    final versions = appArchiveDecoded.items
        .where((element) => element.platform == Platform.operatingSystem)
        .toList();

    if (versions.isEmpty) {
      throw Exception("Desktop Updater: No version found for this platform");
    }

    final latestVersion = versions.reduce(
      (value, element) {
        if (value.shortVersion > element.shortVersion) {
          return value;
        }
        return element;
      },
    );

    print("Latest version: ${latestVersion.shortVersion}");

    String? currentVersion;

    if (Platform.isLinux) {
      final exePath = await File("/proc/self/exe").resolveSymbolicLinks();
      final appPath = path.dirname(exePath);
      final assetPath = path.join(appPath, "data", "flutter_assets");
      final versionPath = path.join(assetPath, "version.json");
      final versionJson = jsonDecode(await File(versionPath).readAsString());
      currentVersion = versionJson["build_number"];
      print("Current version: $currentVersion");
    } else {
      currentVersion = await DesktopUpdater().getCurrentVersion();
      print("Current version: $currentVersion");
    }

    if (currentVersion == null) {
      throw Exception("Desktop Updater: Current version is null");
    }

    if (latestVersion.shortVersion > int.parse(currentVersion)) {
      print("New version found: ${latestVersion.version}");

      return latestVersion.copyWith(
        changedFiles: null,
        appName: appArchiveDecoded.appName,
      );
    } else {
      print("No new version found");
    }
  }

  return null;
}
