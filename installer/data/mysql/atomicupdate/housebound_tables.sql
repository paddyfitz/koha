CREATE TABLE IF NOT EXISTS `housebound` (
  `hbnumber` int(11) NOT NULL auto_increment,
  `day` text NOT NULL,
  `frequency` text,
  `borrowernumber` int(11) default NULL,
  `Itype_quant` varchar(10) default NULL,
  `Item_subject` text,
  `Item_authors` text,
  `referral` text,
  `notes` text,
  PRIMARY KEY  (`hbnumber`),
  KEY `borrowernumber` (`borrowernumber`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 ;



CREATE TABLE IF NOT EXISTS `housebound_instance` (
  `instanceid` int(11) NOT NULL auto_increment,
  `hbnumber` int(11) NOT NULL,
  `dmy` date default NULL,
  `time` text,
  `borrowernumber` int(11) NOT NULL,
  `volunteer` int(11) default NULL,
  `chooser` int(11) default NULL,
  `deliverer` int(11) default NULL,
  PRIMARY KEY  (`instanceid`),
  KEY `hbnumber` (`hbnumber`,`borrowernumber`,`volunteer`,`chooser`,`deliverer`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 ;

insert into systempreferences (variable,value,options,explanation,type) values 
('useHouseboundModule',1,'','If ON, use the Housebound module','YesNo');

insert into systempreferences (variable,value,options,explanation,type) values 
('useHouseboundCheckPrevious',1,'','If ON, checks if Housebound patrons have previous issued items to be checked out',
'YesNo');

insert into categories (categorycode, description, enrolmentperiod, upperagelimit, dateofbirthrequired, category_type) 
values ('VOL','Housebound volunteer','99','999','1','A');