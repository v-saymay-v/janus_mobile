drop table if exists bt_user;
create table bt_user (
    c_id text not null,
    n_user int not null,
    n_group int default 0,
    c_name text,
    c_photo text,
    d_last datetime,
    n_unread int,
    primary key (c_id)
);

drop table if exists bt_message;
create table bt_message (
    n_message int not null,
    c_owner text not null,
    n_writer int not null,
    d_write datetime,
    c_contents text,
    b_send int,
    b_read int,
    c_attach text,
    c_type text,
    c_name text,
    primary key (n_message)
);
