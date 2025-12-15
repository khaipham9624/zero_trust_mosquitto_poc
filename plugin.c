#include <stdio.h>
#include <string.h>

#include <mosquitto.h>
#include <mosquitto_plugin.h>
#include <mosquitto_broker.h>
#include <time.h>
#define MAX_BLACKLIST 128
#define MAX_ID_LEN    64


#define MAX_CLIENTS 128
#define RATE_LIMIT  5     // messages
#define TIME_WINDOW 5     // seconds

struct client_rate {
    char clientid[64];
    int count;
    time_t window_start;
};

static struct client_rate rates[MAX_CLIENTS];
static int rate_count = 0;

static char blacklist[MAX_BLACKLIST][MAX_ID_LEN];
static int blacklist_count = 0;

static struct client_rate *get_rate(const char *clientid)
{
    time_t now = time(NULL);

    for (int i = 0; i < rate_count; i++) {
        if (strcmp(rates[i].clientid, clientid) == 0) {
            /* reset window nếu quá thời gian */
            if (now - rates[i].window_start > TIME_WINDOW) {
                rates[i].count = 0;
                rates[i].window_start = now;
            }
            return &rates[i];
        }
    }

    if (rate_count < MAX_CLIENTS) {
        strncpy(rates[rate_count].clientid,
                clientid, sizeof(rates[rate_count].clientid) - 1);
        rates[rate_count].count = 0;
        rates[rate_count].window_start = now;
        return &rates[rate_count++];
    }

    return NULL;
}


static void blacklist_add(const char *clientid)
{
    if (!clientid) return;

    for (int i = 0; i < blacklist_count; i++) {
        if (strcmp(blacklist[i], clientid) == 0)
            return; // đã có
    }

    if (blacklist_count < MAX_BLACKLIST) {
        strncpy(blacklist[blacklist_count],
                clientid, MAX_ID_LEN - 1);
        blacklist_count++;
    }
}

static int is_blacklisted(const char *clientid)
{
    if (!clientid) return 0;

    for (int i = 0; i < blacklist_count; i++) {
        if (strcmp(blacklist[i], clientid) == 0)
            return 1;
    }
    return 0;
}

static int basic_auth(int event, void *event_data, void *userdata)
{
    struct mosquitto_evt_basic_auth *ed = event_data;
    const char *clientid = mosquitto_client_id(ed->client);

    if (is_blacklisted(clientid)) {
        mosquitto_log_printf(MOSQ_LOG_WARNING,
            "[BL] reject blacklisted clientid=%s",
            clientid);
        return MOSQ_ERR_AUTH;
    }

    return MOSQ_ERR_SUCCESS;
}


/* ===================================================== */
/* Plugin version – BẮT BUỘC */
int mosquitto_plugin_version(int supported_version_count,
                             const int *supported_versions)
{
    for (int i = 0; i < supported_version_count; i++) {
        if (supported_versions[i] == MOSQ_PLUGIN_VERSION)
            return MOSQ_PLUGIN_VERSION;
    }
    return -1;
}


// static int acl_check(int event, void *event_data, void *userdata)
// {
//     struct mosquitto_evt_acl_check *ed = event_data;
//     const char *clientid = mosquitto_client_id(ed->client);

//     if (ed->access == MOSQ_ACL_SUBSCRIBE &&
//         strcmp(ed->topic, "#") == 0) {

//         mosquitto_log_printf(MOSQ_LOG_WARNING,
//             "[BL] kick clientid=%s (subscribe #)",
//             clientid);

//         blacklist_add(clientid);

//         mosquitto_disconnect_client(
//             ed->client,
//             MOSQ_ERR_NOT_AUTHORIZED,
//             NULL
//         );

//         return MOSQ_ERR_ACL_DENIED;
//     }

//     return MOSQ_ERR_ACL_DENIED;
// }

/* ===================================================== */
/* ACL CHECK: kiểm soát publish / subscribe */
static int acl_check(int event, void *event_data, void *userdata)
{
    struct mosquitto_evt_acl_check *ed = event_data;
    const char *clientid = mosquitto_client_id(ed->client);
    const char *topic = ed->topic;
    mosquitto_log_printf(MOSQ_LOG_INFO, "check acl client %s\n", clientid);

    if (!clientid || !topic)
        return MOSQ_ERR_ACL_DENIED;

    /* Rule ví dụ */
    char allow_pub[256];
    snprintf(allow_pub, sizeof(allow_pub),
             "device/%s/tx", clientid);

    if (ed->access == MOSQ_ACL_READ || ed->access == MOSQ_ACL_SUBSCRIBE || (ed->access == MOSQ_ACL_WRITE &&
        strcmp(topic, allow_pub) == 0)) {
        return MOSQ_ERR_SUCCESS;
    }

    return MOSQ_ERR_ACL_DENIED;
}

static int on_message(int event, void *event_data, void *userdata)
{
    struct mosquitto_evt_message *ed = event_data;
    const char *clientid = mosquitto_client_id(ed->client);
    time_t now = time(NULL);

    if (!clientid)
        return MOSQ_ERR_SUCCESS;

    /* nếu đã blacklist thì kick luôn */
    if (is_blacklisted(clientid)) {
        mosquitto_kick_client_by_clientid(
            clientid,
            false
        );
        return MOSQ_ERR_SUCCESS;
    }

    struct client_rate *r = get_rate(clientid);
    if (!r)
        return MOSQ_ERR_SUCCESS;

    r->count++;

    if (r->count > RATE_LIMIT &&
        (now - r->window_start) <= TIME_WINDOW) {

        mosquitto_log_printf(MOSQ_LOG_WARNING,
            "[RL] client=%s exceeded rate (%d/%ds) -> kick",
            clientid, RATE_LIMIT, TIME_WINDOW);

        blacklist_add(clientid);

        mosquitto_kick_client_by_clientid(
            clientid,
            false
        );
    }

    return MOSQ_ERR_SUCCESS;
}
/* ===================================================== */
/* Init */
int mosquitto_plugin_init(mosquitto_plugin_id_t *id,
                          void **userdata,
                          struct mosquitto_opt *opts,
                          int opt_count)
{
    mosquitto_log_printf(MOSQ_LOG_NOTICE,
        "[ZT] plugin init");
    mosquitto_callback_register(
        id, 
        MOSQ_EVT_BASIC_AUTH, 
        basic_auth, NULL, NULL);
    mosquitto_callback_register(
        id,
        MOSQ_EVT_ACL_CHECK,
        acl_check,
        NULL, NULL);
    mosquitto_callback_register(id,
        MOSQ_EVT_MESSAGE,
        on_message,
        NULL, NULL);

    return MOSQ_ERR_SUCCESS;
}

/* ===================================================== */
/* Cleanup */
int mosquitto_plugin_cleanup(void *userdata,
                             struct mosquitto_opt *opts,
                             int opt_count)
{
    return MOSQ_ERR_SUCCESS;
}
