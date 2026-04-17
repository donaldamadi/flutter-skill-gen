// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pattern_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatternInfo _$PatternInfoFromJson(Map<String, dynamic> json) => PatternInfo(
  architecture: json['architecture'] as String?,
  stateManagement: json['state_management'] as String?,
  routing: json['routing'] as String?,
  di: json['di'] as String?,
  apiClient: json['api_client'] as String?,
  errorHandling: json['error_handling'] as String?,
  modelApproach: json['model_approach'] as String?,
  i18n: json['i18n'] as String?,
);

Map<String, dynamic> _$PatternInfoToJson(PatternInfo instance) =>
    <String, dynamic>{
      'architecture': instance.architecture,
      'state_management': instance.stateManagement,
      'routing': instance.routing,
      'di': instance.di,
      'api_client': instance.apiClient,
      'error_handling': instance.errorHandling,
      'model_approach': instance.modelApproach,
      'i18n': instance.i18n,
    };
