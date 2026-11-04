# device_calendar serializa/desserializa seus modelos com Gson por reflexão.
# Sem estas regras o R8 renomeia os campos e o release devolve dados vazios.
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
-keep class com.builttoroam.devicecalendar.** { *; }
-keep class com.google.gson.** { *; }
-keep class org.dmfs.rfc5545.** { *; }
-dontwarn org.dmfs.**
