ALTER TABLE issuingrules ADD COLUMN overduefinescap decimal default NULL;
UPDATE systempreferences SET value = NULL where variable = 'MaxFine' and value > 899;
UPDATE issuingrules SET overduefinescap = (
    SELECT value from systempreferences WHERE variable = 'MaxFine');
UPDATE systempreferences SET value = NULL where variable = 'MaxFine';
UPDATE systempreferences SET explanation =
'Maximum fine a patron can have for all late returns at one moment. Single item caps are specified in the circulation rules matrix.' WHERE variable = 'MaxFine';
