import 'package:flutter/foundation.dart';
import 'package:tasker_nlp/tasker_nlp.dart';
import 'package:uuid/uuid.dart';

import '../config/env_config.dart';
import '../config/magic_input_parser_config.dart';
import '../nlp/resolve_place_location.dart';
import '../../features/tasks/domain/task.dart';
import '../../features/tasks/presentation/state/task_store.dart';
import 'location_service.dart';

/// Monta uma [Task] a partir de texto livre — mesma lógica do [MagicTaskInput].
class MagicTaskBuilder {
  MagicTaskBuilder._();

  static const _uuid = Uuid();

  /// Interpreta [text] com NLP local ou Gemini e retorna a tarefa pronta para salvar.
  static Future<Task> buildFromText({
    required String text,
    DateTime? referenceDate,
    bool resolveLocation = true,
    bool useGemini = true,
  }) async {
    final ref = TaskStore.dateOnly(referenceDate ?? DateTime.now());

    if (useGemini &&
        MagicInputParserConfig.useGeminiParser &&
        EnvConfig.isGeminiConfigured) {
      try {
        return await _buildWithGemini(
          text: text,
          referenceDate: ref,
          resolveLocation: resolveLocation,
        );
      } catch (e, st) {
        debugPrint(
          'MagicTaskBuilder: Gemini indisponível, usando NLP local: $e\n$st',
        );
      }
    }

    return _buildWithLocalNlp(
      text: text,
      referenceDate: ref,
      resolveLocation: resolveLocation,
    );
  }

  static Future<Task> _buildWithLocalNlp({
    required String text,
    required DateTime referenceDate,
    required bool resolveLocation,
  }) async {
    final normalized = dedupeRepeatedSpeech(text.trim());
    final placeExtract = extractPlacePTBR(normalized);
    final errandExtract = extractErrandListPTBR(
      normalized,
      place: placeExtract,
    );
    final parsed = extractWhenPTBR(normalized, referenceDate);
    final icon = inferTaskIconPTBR(normalized);

    var rawTitle = (parsed.title.isNotEmpty ? parsed.title : normalized).trim();
    if (placeExtract != null) {
      rawTitle = stripPlaceFromTitle(rawTitle, placeExtract);
      if (rawTitle.isEmpty) {
        rawTitle = stripPlaceFromTitle(normalized, placeExtract);
      }
    }
    if (errandExtract != null) {
      rawTitle = stripErrandFromTitle(rawTitle, errandExtract);
    }

    String title;
    if (errandExtract != null) {
      title = resolveErrandDisplayTitle(
        primaryTitle: '',
        place: placeExtract,
        errand: errandExtract,
        errandItems: errandExtract.items,
      );
    } else {
      title = _capFirst(
        rawTitle.isNotEmpty
            ? rawTitle
            : (parsed.title.isNotEmpty ? parsed.title : normalized),
      );
      if (placeExtract != null &&
          looksLikeSingleErrandAction(normalized)) {
        final actionTitle = extractCoreActionTitlePTBR(
          normalized,
          place: placeExtract,
        );
        if (actionTitle != null && actionTitle.trim().isNotEmpty) {
          title = actionTitle.trim();
        }
      } else if (placeExtract != null) {
        title = _capFirst(
          enrichTitleWithPlaceDestination(
            title: title,
            placeQuery: placeExtract.searchQuery,
          ),
        );
      }
    }
    title = _capFirst(
      enrichTitleWithTranscriptContext(
        title: title,
        transcript: normalized,
        placeQuery: placeExtract?.searchQuery,
      ),
    );

    final data = parsed.dateYmd ?? TaskStore.formatDateYmd(referenceDate);
    final hora = parsed.timeHHMM ?? '';

    TaskLocation? location;
    if (resolveLocation &&
        placeExtract != null &&
        !placeExtract.skipGeocoding) {
      var near = await LocationService.getQuickLocationForMap();
      near ??= await LocationService.refineLocationForMap();
      final resolved = await resolvePlaceLocation(placeExtract, near: near);
      location = resolved?.location;
    }

    final now = DateTime.now();

    return Task(
      id: _uuid.v4(),
      title: title,
      descricao: errandExtract?.description ?? '',
      data: data,
      hora: hora,
      location: location,
      iconKey: icon.iconKey,
      iconBackgroundArgb: icon.backgroundArgb,
      createdAt: now,
      lastUpdated: now,
    );
  }

  static Future<Task> _buildWithGemini({
    required String text,
    required DateTime referenceDate,
    required bool resolveLocation,
  }) async {
    final normalized = dedupeRepeatedSpeech(text.trim());

    final parsed = await GeminiMagicTaskParser.parseTaskFromText(
      transcript: normalized,
      referenceDate: referenceDate,
      apiKey: EnvConfig.geminiApiKey,
      geminiModel: MagicInputParserConfig.geminiModel,
    );

    final nlpIcon = inferTaskIconPTBR(normalized);
    final iconKey = parsed.iconKey != null
        ? GeminiMagicTaskParser.resolveIconKey(parsed.iconKey)
        : nlpIcon.iconKey;
    final iconBackgroundArgb = parsed.iconKey != null
        ? GeminiMagicTaskParser.resolveIconBackgroundArgb(iconKey)
        : nlpIcon.backgroundArgb;

    final data = parsed.dateYmd ?? TaskStore.formatDateYmd(referenceDate);
    final hora = parsed.timeHHMM ?? '';

    final descricao = parsed.errandItems.isEmpty
        ? ''
        : formatErrandDescription(parsed.errandItems);

    var title = _capFirst(parsed.title);
    if (parsed.errandItems.isNotEmpty) {
      final placeForTitle = parsed.placeSearchQuery != null
          ? ExtractPlaceResult(
              searchQuery: parsed.placeSearchQuery!,
              matchedText: parsed.placeSearchQuery!,
              skipGeocoding: parsed.placeSkipGeocoding,
            )
          : null;
      final errandExtract = extractErrandListPTBR(
        normalized,
        place: placeForTitle,
      );
      title = _capFirst(
        resolveErrandDisplayTitle(
          primaryTitle: parsed.title,
          place: placeForTitle,
          errand: errandExtract,
          errandItems: parsed.errandItems,
        ),
      );
    }

    TaskLocation? location;
    if (resolveLocation &&
        parsed.placeSearchQuery != null &&
        !parsed.placeSkipGeocoding) {
      final placeExtract = ExtractPlaceResult(
        searchQuery: parsed.placeSearchQuery!,
        matchedText: parsed.placeDisplayName ?? parsed.placeSearchQuery!,
        skipGeocoding: false,
      );
      var near = await LocationService.getQuickLocationForMap();
      near ??= await LocationService.refineLocationForMap();
      final resolved = await resolvePlaceLocation(placeExtract, near: near);
      location = resolved?.location.copyWith(
        name: parsed.placeDisplayName ?? resolved.location.name,
      );
    }

    final now = DateTime.now();

    return Task(
      id: _uuid.v4(),
      title: title,
      descricao: descricao,
      data: data,
      hora: hora,
      location: location,
      iconKey: iconKey,
      iconBackgroundArgb: iconBackgroundArgb,
      createdAt: now,
      lastUpdated: now,
    );
  }

  static String _capFirst(String str) {
    final match = RegExp(r'^\s*(\p{L})', unicode: true).firstMatch(str);
    if (match == null) return str;
    final start = match.start;
    final letter = match.group(1)!;
    return str.replaceRange(start, match.end, letter.toUpperCase());
  }
}
