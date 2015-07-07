create table `jenkins` (
    `id` integer unsigned not null auto_increment,
    `branch` varchar(512) not null,
    `count` integer unsigned,
    `build_number` varchar(64),
    PRIMARY KEY (`id`),
    KEY `build_number_idx` (`build_number`)
);
