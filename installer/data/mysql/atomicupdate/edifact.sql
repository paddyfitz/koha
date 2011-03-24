CREATE TABLE IF NOT EXISTS `vendor_edi_accounts` (
  `id` int(11) NOT NULL auto_increment,
  `description` text NOT NULL,
  `host` text,
  `username` text,
  `password` text,
  `last_activity` date default NULL,
  `provider` int(11) default NULL,
  `path` text,
  `in_dir` text,
  `san` varchar(10) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `edifact_messages` (
  `key` int(11) NOT NULL auto_increment,
  `message_type` text NOT NULL,
  `date_sent` date default NULL,
  `provider` int(11) default NULL,
  `status` text,
  `basketno` int(11) NOT NULL default '0',
  PRIMARY KEY  (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

insert into permissions (module_bit, code, description) values (13, 'edi_manage', 'Manage EDIFACT transmissions');