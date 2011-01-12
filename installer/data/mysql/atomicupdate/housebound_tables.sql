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