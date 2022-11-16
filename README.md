# MySQL Load Balancer

| Container |    Job     |
|:---------:|:----------:|
|   w101    |  Write DB  |
|   r201    | Read DB #1 |
|   r202    | Read DB #2 |
|   r203    | Read DB #3 |

### Start the containers

```bash
bash build.sh
```

### Access Databases

#### Access Master DB (WriteDB101)

```bash
mysql -uroot -p 0a43fdd132ad -h 127.0.0.1 -P 13306
```

```sql
SELECT @@HOSTNAME;
SELECT @@SERVER_ID;
SHOW MASTER STATUS;
```

#### Access Read DBs

```bash
mysql -uroot -p 0a43fdd132ad -h 127.0.0.1 -P 23306
```

```sql
SELECT @@HOSTNAME;
SELECT @@SERVER_ID;
SHOW MASTER STATUS;
```


