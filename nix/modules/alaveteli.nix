{
  config,
  lib,
  pkgs,
  hostname,
  inputs,
  ...
}:
let
  # geoipLicenseKeyFile = pkgs
  themeFiles = ../../.;
  cfg = config.services.alaveteli;
in
{

  services.alaveteli = {
    enable = true;
    domainName = "handlingar.furosu.fr";
    database.passwordFile = "${config.sops.secrets."alaveteli_db_password".path}";
    database.createLocally = true;
    geoipLicenseKey = config.sops.secrets."maxmind_license_key".path;
    mailserver = {
      createLocally = true;
      rootAlias = "handlingarnix@where.tf";
    };
    theme = {
      url = "https://github.com/laurentS/handlingar-theme.git";
      files = themeFiles;
    };

    settings = {
      general = {
        SITE_NAME = "Handlingar TEST";
        ISO_COUNTRY_CODE = "SE";
        ISO_CURRENCY_CODE = "SEK";
        TIME_ZONE = "Europe/Stockholm";
        AVAILABLE_LOCALES = "en sv";
        DEFAULT_LOCALE = "sv";
        INCLUDE_DEFAULT_LOCALE_IN_URLS = true;
        REPLY_LATE_AFTER_DAYS = 31;
        WORKING_OR_CALENDAR_DAYS = "calendar";
        # effectively disable very late status, it will only happen 100 years after the
        # initial request was sent.
        REPLY_VERY_LATE_AFTER_DAYS = 36500;
        # 100 ans pour éviter que les requêtes ne soient verrouillées après 6 mois, ce qui
        # empêche les mails entrants d'être acceptés. Avec ce réglage, ce verrouillage ne
        # devrait plus avoir lieu.
        RESTRICT_NEW_RESPONSES_ON_OLD_REQUESTS_AFTER_MONTHS = 1200;

        OVERRIDE_ALL_PUBLIC_BODY_REQUEST_EMAILS = cfg.mailserver.rootAlias;
      };
    };
  };
}
