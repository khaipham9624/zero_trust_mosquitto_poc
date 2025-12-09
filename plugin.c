#include <stdio.h>
#include <string.h>
#include <mosquitto_broker.h>
#include <mosquitto_plugin.h>
#include <mosquitto.h>
#include <time.h>

static mosquitto_plugin_id_t *plg_id;

/* Track publish rate per client */
typedef struct {
    char client_id[128];
    long last_pub_ts;
} client_info_t;

static client_info_t client_db[1024];
static int client_count = 0;

static long now_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static long get_last_pub(const char *client_id) {
    for(int i=0;i<client_count;i++){
        if(strcmp(client_db[i].client_id, client_id)==0)
            return client_db[i].last_pub_ts;
    }
    return -1;
}

static void update_pub(const char *client_id) {
    for(int i=0;i<client_count;i++){
        if(strcmp(client_db[i].client_id, client_id)==0){
            client_db[i].last_pub_ts = now_ms();
            return;
        }
    }
    strcpy(client_db[client_count].client_id, client_id);
    client_db[client_count].last_pub_ts = now_ms();
    client_count++;
}

/* MAIN HOOK - when PUB or SUB occurs */
int mosquitto_auth_acl_check_v2(
    mosquitto_plugin_id_t *plugin_id,
    int event,
    struct mosquitto *client,
    const char *topic,
    int access,
    const void *payload,
    int payloadlen)
{
    const char *client_id = mosquitto_client_id(client);

    printf("[PLUGIN] Client=%s Access=%d Topic=%s\n",
        client_id, access, topic);

    /* Handle SUBSCRIBE */
    if(access == MOSQ_ACL_SUBSCRIBE){
        printf("  -> SUBSCRIBE request accepted\n");
        return MOSQ_ERR_SUCCESS;
    }

    /* Handle PUBLISH */
    if(access == MOSQ_ACL_WRITE){
        long last = get_last_pub(client_id);
        long now  = now_ms();

        if(last > 0 && (now - last) < 5000){
            printf("  -> ANOMALY: publish too fast (%ld ms)\n",
                now - last);
            return MOSQ_ERR_ACL_DENIED;
        }

        update_pub(client_id);
        printf("  -> PUBLISH accepted\n");
        return MOSQ_ERR_SUCCESS;
    }

    return MOSQ_ERR_SUCCESS;
}

/* Plugin init */
int mosquitto_plugin_init(mosquitto_plugin_id_t *identifier, void **userdata, struct mosquitto_opt *options, int option_count)
{
    plg_id = identifier;
    mosquitto_log_printf(MOSQ_LOG_INFO, "[PLUGIN] Zero Trust plugin loaded");
    return MOSQ_ERR_SUCCESS;
}

/* Cleanup */
int mosquitto_plugin_cleanup(void *userdata, struct mosquitto_opt *options, int option_count)
{
    mosquitto_log_printf(MOSQ_LOG_INFO, "[PLUGIN] Zero Trust plugin unloaded");
    return MOSQ_ERR_SUCCESS;
}
