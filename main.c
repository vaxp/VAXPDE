/*
 * Simple bottom dock using GTK3
 * Features:
 * - Undecorated always-on-top window docked to bottom center
 * - Rounded corners and semi-transparent "glass" background via CSS
 * - Favorite application buttons (launch simple commands)
 * - "Show apps" button opens a dialog listing .desktop files and allows launching
 *
 * Build: make
 * Requires: GTK+ 3 development libraries (pkg-config gtk+-3.0)
 */

#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <stdlib.h>
#include <string.h>
/* Acknowledge that libwnck API is not stable */
#define WNCK_I_KNOW_THIS_IS_UNSTABLE
#include <libwnck/libwnck.h>

/* Favorites management */
typedef struct {
    char *name;
    char *exec;
    char *icon;
} FavoriteApp;

static GPtrArray *g_favorites = NULL;
static GtkWidget *g_dock_box = NULL;  /* The main dock box for favorites */
static WnckScreen *g_wnck_screen = NULL;

/* launcher window pointer (declared early so functions above can reference it) */
static GtkWidget *g_launcher_window = NULL;

/* Forward declarations */
static void update_favorites_bar(void);
static void show_app_context_menu(GtkWidget *btn, GdkEventButton *event);
static void launch_command(const char *cmd);

/* A tiny helper to launch a command asynchronously */
static void
launch_command(const char *cmd)
{
    /* Hide launcher if open so it disappears when launching an app */
    if (g_launcher_window && GTK_IS_WIDGET(g_launcher_window)) {
        gtk_widget_hide(g_launcher_window);
    }

    if (cmd == NULL || *cmd == '\0')
        return;
    /* spawn asynchronously, ignore errors here */
    g_spawn_command_line_async(cmd, NULL);
}

/* Button press handler for app buttons */
static gboolean on_app_button_press(GtkWidget *widget, GdkEventButton *event, gpointer data) {
    if (event->button == 3) { /* right click */
        show_app_context_menu(widget, event);
        return TRUE;
    } else if (event->button == 1) { /* left click */
        const char *cmd = g_object_get_data(G_OBJECT(widget), "app-exec");
        launch_command(cmd);
        return TRUE;
    }
    return FALSE;
}

/* Parse a .desktop file to extract Name, Exec and Icon (small parser) */
typedef struct {
    char *name;
    char *exec;
    char *icon;
    char *path;
    gboolean nodisplay;
    gboolean hidden;
    char *only_show_in;
    char *not_show_in;
} AppEntry;

static AppEntry *parse_desktop_file(const char *filepath)
{
    GError *err = NULL;
    gchar *content = NULL;
    if (!g_file_get_contents(filepath, &content, NULL, &err)) {
        g_clear_error(&err);
        return NULL;
    }

    AppEntry *e = g_new0(AppEntry, 1);
    e->path = g_strdup(filepath);

    gchar **lines = g_strsplit(content, "\n", -1);
    for (gchar **l = lines; *l; ++l) {
        gchar *line = *l;
        if (line[0] == '#' || line[0] == '\0') continue;
        if (g_str_has_prefix(line, "Name=")) {
            g_free(e->name);
            e->name = g_strdup(line + 5);
        } else if (g_str_has_prefix(line, "Exec=")) {
            g_free(e->exec);
            /* strip field codes like %U %u %f etc */
            gchar *tmp = g_strdup(line + 5);
            for (char *p = tmp; *p; ++p) {
                if (*p == '%') { *p = '\0'; break; }
            }
            gchar *trim = g_strstrip(tmp);
            e->exec = g_strdup(trim);
            g_free(tmp);
        } else if (g_str_has_prefix(line, "Icon=")) {
            g_free(e->icon);
            e->icon = g_strdup(line + 5);
        } else if (g_str_has_prefix(line, "NoDisplay=")) {
            gchar *v = g_strdup(line + 10);
            g_strstrip(v);
            e->nodisplay = (g_ascii_strcasecmp(v, "true") == 0);
            g_free(v);
        } else if (g_str_has_prefix(line, "Hidden=")) {
            gchar *v = g_strdup(line + 7);
            g_strstrip(v);
            e->hidden = (g_ascii_strcasecmp(v, "true") == 0);
            g_free(v);
        } else if (g_str_has_prefix(line, "OnlyShowIn=")) {
            g_free(e->only_show_in);
            e->only_show_in = g_strdup(line + 11);
        } else if (g_str_has_prefix(line, "NotShowIn=")) {
            g_free(e->not_show_in);
            e->not_show_in = g_strdup(line + 10);
        }
    }
    g_strfreev(lines);
    g_free(content);

    if (!e->name && !e->exec && !e->icon && !e->only_show_in && !e->not_show_in) {
        g_free(e->name); g_free(e->exec); g_free(e->icon); g_free(e->path);
        g_free(e->only_show_in); g_free(e->not_show_in);
        g_free(e);
        return NULL;
    }
    return e;
}

/* Global cached app entries for launcher */
static GPtrArray *g_app_entries = NULL;

/* forward declarations */
static void on_launcher_destroy(GtkWidget *w, gpointer user_data);
static void on_search_changed(GtkSearchEntry *entry, gpointer user_data);
static void show_app_launcher(GtkWindow *parent);

static void free_app_entries(void)
{
    if (!g_app_entries) return;
    for (guint i = 0; i < g_app_entries->len; ++i) {
        AppEntry *ae = g_ptr_array_index(g_app_entries, i);
        g_free(ae->name); g_free(ae->exec); g_free(ae->icon); g_free(ae->path);
        g_free(ae->only_show_in); g_free(ae->not_show_in);
        g_free(ae);
    }
    g_ptr_array_free(g_app_entries, TRUE);
    g_app_entries = NULL;
}

/* Save favorites to config file */
static void save_favorites(void)
{
    if (!g_favorites) return;
    
    gchar *config_dir = g_build_filename(g_get_user_config_dir(), "dock", NULL);
    g_mkdir_with_parents(config_dir, 0755);
    gchar *config_file = g_build_filename(config_dir, "favorites.conf", NULL);
    
    GString *data = g_string_new("");
    for (guint i = 0; i < g_favorites->len; ++i) {
        FavoriteApp *app = g_ptr_array_index(g_favorites, i);
        g_string_append_printf(data, "Name=%s\nExec=%s\nIcon=%s\n\n",
            app->name ? app->name : "",
            app->exec ? app->exec : "",
            app->icon ? app->icon : "");
    }
    
    g_file_set_contents(config_file, data->str, -1, NULL);
    g_string_free(data, TRUE);
    g_free(config_file);
    g_free(config_dir);
}

/* Load favorites from config file */
static void load_favorites(void)
{
    if (!g_favorites) {
        g_favorites = g_ptr_array_new();
    }
    
    gchar *config_file = g_build_filename(g_get_user_config_dir(), "dock", "favorites.conf", NULL);
    gchar *content = NULL;
    if (g_file_get_contents(config_file, &content, NULL, NULL)) {
        gchar **lines = g_strsplit(content, "\n", -1);
        FavoriteApp *current = NULL;
        
        for (gchar **l = lines; *l; ++l) {
            gchar *line = g_strstrip(*l);
            if (*line == '\0') {
                if (current) {
                    g_ptr_array_add(g_favorites, current);
                    current = NULL;
                }
                continue;
            }
            
            if (!current) {
                current = g_new0(FavoriteApp, 1);
            }
            
            if (g_str_has_prefix(line, "Name=")) {
                current->name = g_strdup(line + 5);
            } else if (g_str_has_prefix(line, "Exec=")) {
                current->exec = g_strdup(line + 5);
            } else if (g_str_has_prefix(line, "Icon=")) {
                current->icon = g_strdup(line + 5);
            }
        }
        
        if (current) {
            g_ptr_array_add(g_favorites, current);
        }
        
        g_strfreev(lines);
        g_free(content);
    }
    g_free(config_file);
}

/* Load all .desktop entries into global cache. Safe to call multiple times. */
static void load_all_desktop_entries(void)
{
    if (g_app_entries) return; /* already loaded */
    g_app_entries = g_ptr_array_new();

    const char *dirs[] = { "/usr/share/applications", "/usr/local/share/applications", NULL };
    gchar *home_apps = g_build_filename(g_get_home_dir(), ".local", "share", "applications", NULL);

    for (const char **d = dirs; *d; ++d) {
        GDir *dir = g_dir_open(*d, 0, NULL);
        if (!dir) continue;
        const char *name;
        while ((name = g_dir_read_name(dir))) {
            if (!g_str_has_suffix(name, ".desktop")) continue;
            gchar *path = g_build_filename(*d, name, NULL);
            AppEntry *e = parse_desktop_file(path);
            g_free(path);
            if (!e) continue;
            /* filter hidden / nodisplay and desktop-specific entries */
            gboolean add = TRUE;
            if (e->nodisplay || e->hidden) add = FALSE;
            if (add && e->only_show_in && *e->only_show_in) {
                const char *xd = getenv("XDG_CURRENT_DESKTOP");
                if (!xd) xd = getenv("DESKTOP_SESSION");
                if (!xd) xd = "";
                gboolean found = FALSE;
                gchar **tokens = g_strsplit(e->only_show_in, ";", -1);
                for (gchar **t = tokens; *t; ++t) {
                    gchar *tok = g_strstrip(*t);
                    if (*tok == '\0') continue;
                    if (g_ascii_strcasecmp(tok, xd) == 0) { found = TRUE; break; }
                }
                g_strfreev(tokens);
                if (!found) add = FALSE;
            }
            if (add && e->not_show_in && *e->not_show_in) {
                const char *xd = getenv("XDG_CURRENT_DESKTOP");
                if (!xd) xd = getenv("DESKTOP_SESSION");
                if (!xd) xd = "";
                gchar **tokens = g_strsplit(e->not_show_in, ";", -1);
                for (gchar **t = tokens; *t; ++t) {
                    gchar *tok = g_strstrip(*t);
                    if (*tok == '\0') continue;
                    if (g_ascii_strcasecmp(tok, xd) == 0) { add = FALSE; break; }
                }
                g_strfreev(tokens);
            }
            if (add) g_ptr_array_add(g_app_entries, e);
            else {
                g_free(e->name); g_free(e->exec); g_free(e->icon); g_free(e->path);
                g_free(e->only_show_in); g_free(e->not_show_in); g_free(e);
            }
        }
        g_dir_close(dir);
    }

    GDir *udir = g_dir_open(home_apps, 0, NULL);
    if (udir) {
        const char *name;
        while ((name = g_dir_read_name(udir))) {
            if (!g_str_has_suffix(name, ".desktop")) continue;
            gchar *path = g_build_filename(home_apps, name, NULL);
            AppEntry *e = parse_desktop_file(path);
            g_free(path);
            if (!e) continue;
            gboolean add = TRUE;
            if (e->nodisplay || e->hidden) add = FALSE;
            if (add && e->only_show_in && *e->only_show_in) {
                const char *xd = getenv("XDG_CURRENT_DESKTOP");
                if (!xd) xd = getenv("DESKTOP_SESSION");
                if (!xd) xd = "";
                gboolean found = FALSE;
                gchar **tokens = g_strsplit(e->only_show_in, ";", -1);
                for (gchar **t = tokens; *t; ++t) {
                    gchar *tok = g_strstrip(*t);
                    if (*tok == '\0') continue;
                    if (g_ascii_strcasecmp(tok, xd) == 0) { found = TRUE; break; }
                }
                g_strfreev(tokens);
                if (!found) add = FALSE;
            }
            if (add && e->not_show_in && *e->not_show_in) {
                const char *xd = getenv("XDG_CURRENT_DESKTOP");
                if (!xd) xd = getenv("DESKTOP_SESSION");
                if (!xd) xd = "";
                gchar **tokens = g_strsplit(e->not_show_in, ";", -1);
                for (gchar **t = tokens; *t; ++t) {
                    gchar *tok = g_strstrip(*t);
                    if (*tok == '\0') continue;
                    if (g_ascii_strcasecmp(tok, xd) == 0) { add = FALSE; break; }
                }
                g_strfreev(tokens);
            }
            if (add) g_ptr_array_add(g_app_entries, e);
            else {
                g_free(e->name); g_free(e->exec); g_free(e->icon); g_free(e->path);
                g_free(e->only_show_in); g_free(e->not_show_in); g_free(e);
            }
        }
        g_dir_close(udir);
    }
    g_free(home_apps);
}

/* Create and show a non-modal application launcher window (grid + search) */
static void show_app_launcher(GtkWindow *parent)
{
    load_all_desktop_entries();

    if (g_launcher_window) {
        gtk_window_present(GTK_WINDOW(g_launcher_window));
        return;
    }

    GdkScreen *screen = gdk_screen_get_default();
    GdkVisual *visual = gdk_screen_get_rgba_visual(screen);

    g_launcher_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    /* Use RGBA visual for transparency if available */
    if (visual) gtk_widget_set_visual(g_launcher_window, visual);
    gtk_widget_set_app_paintable(g_launcher_window, TRUE);

    gtk_window_set_transient_for(GTK_WINDOW(g_launcher_window), parent);
    gtk_window_set_title(GTK_WINDOW(g_launcher_window), "Applications");
    /* Make window undecorated and fullscreen */
    gtk_window_set_decorated(GTK_WINDOW(g_launcher_window), FALSE);
    gtk_window_fullscreen(GTK_WINDOW(g_launcher_window));

    /* Add a CSS class to make the window background fully transparent */
    GtkCssProvider *lcss = gtk_css_provider_new();
    const gchar *lstyle = ".launcher-window { background-color: rgba(0,0,0,0); }";
    gtk_css_provider_load_from_data(lcss, lstyle, -1, NULL);
    gtk_style_context_add_provider_for_screen(screen, GTK_STYLE_PROVIDER(lcss), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(lcss);

    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 8);
    gtk_container_add(GTK_CONTAINER(g_launcher_window), vbox);

    GtkWidget *search = gtk_search_entry_new();
    gtk_box_pack_start(GTK_BOX(vbox), search, FALSE, FALSE, 0);

    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_box_pack_start(GTK_BOX(vbox), scrolled, TRUE, TRUE, 0);

    GtkWidget *flow = gtk_flow_box_new();
    gtk_flow_box_set_max_children_per_line(GTK_FLOW_BOX(flow), 6);
    gtk_flow_box_set_selection_mode(GTK_FLOW_BOX(flow), GTK_SELECTION_NONE);
    gtk_container_add(GTK_CONTAINER(scrolled), flow);

    /* populate */
    for (guint i = 0; i < g_app_entries->len; ++i) {
        AppEntry *ae = g_ptr_array_index(g_app_entries, i);
        const char *label = ae->name ? ae->name : (ae->exec ? ae->exec : ae->path);

        GtkWidget *btn = gtk_button_new();
        GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
        GtkWidget *img = NULL;
        if (ae->icon && *ae->icon) {
            img = gtk_image_new_from_icon_name(ae->icon, GTK_ICON_SIZE_DIALOG);
        }
        if (!img) img = gtk_image_new_from_icon_name("application-x-executable", GTK_ICON_SIZE_DIALOG);
        gtk_widget_set_size_request(img, 48, 48);
        gtk_box_pack_start(GTK_BOX(box), img, FALSE, FALSE, 0);
        GtkWidget *lbl = gtk_label_new(label);
        gtk_label_set_max_width_chars(GTK_LABEL(lbl), 14);
        gtk_label_set_ellipsize(GTK_LABEL(lbl), PANGO_ELLIPSIZE_END);
        gtk_box_pack_start(GTK_BOX(box), lbl, FALSE, FALSE, 0);
        gtk_container_add(GTK_CONTAINER(btn), box);

        /* store app data for filtering, launching and favorites */
        g_object_set_data_full(G_OBJECT(btn), "app-name", g_strdup(label), g_free);
        g_object_set_data_full(G_OBJECT(btn), "app-exec", g_strdup(ae->exec ? ae->exec : ""), g_free);
        g_object_set_data_full(G_OBJECT(btn), "app-icon", g_strdup(ae->icon ? ae->icon : ""), g_free);
        
        /* Left click launches, right click shows menu */
        g_signal_connect(btn, "button-press-event", G_CALLBACK(on_app_button_press), NULL);

        gtk_container_add(GTK_CONTAINER(flow), btn);
    }

    /* search handler: filters children by the app-name data */
    g_signal_connect(search, "search-changed", G_CALLBACK(on_search_changed), flow);

    g_signal_connect(g_launcher_window, "destroy", G_CALLBACK(on_launcher_destroy), NULL);

    /* Add class to apply transparent background CSS */
    GtkStyleContext *ctx = gtk_widget_get_style_context(g_launcher_window);
    gtk_style_context_add_class(ctx, "launcher-window");

    gtk_widget_show_all(g_launcher_window);
}

/* Called when the launcher window is destroyed */
static void on_launcher_destroy(GtkWidget *w, gpointer user_data)
{
    (void)user_data;
    g_launcher_window = NULL;
}

/* Callback for removing flash effect */
static gboolean remove_flash_class(gpointer data)
{
    GtkWidget *widget = GTK_WIDGET(data);
    if (!GTK_IS_WIDGET(widget)) return G_SOURCE_REMOVE;
    
    GtkStyleContext *ctx = gtk_widget_get_style_context(widget);
    if (ctx) {
        gtk_style_context_remove_class(ctx, "flash");
        /* Ensure widget is redrawn */
        gtk_widget_queue_draw(widget);
    }
    return G_SOURCE_REMOVE;
}

/* Show a brief flash effect on a widget */
static void flash_widget(GtkWidget *widget)
{
    if (!GTK_IS_WIDGET(widget)) return;
    
    GtkStyleContext *context = gtk_widget_get_style_context(widget);
    if (context) {
        gtk_style_context_add_class(context, "flash");
        /* Ensure widget is redrawn */
        gtk_widget_queue_draw(widget);
        g_timeout_add(500, remove_flash_class, widget);
    }
}

static void remove_from_favorites(const char *exec)
{
    if (!g_favorites) return;
    
    for (guint i = 0; i < g_favorites->len; ++i) {
        FavoriteApp *app = g_ptr_array_index(g_favorites, i);
        if (g_strcmp0(app->exec, exec) == 0) {
            g_free(app->name);
            g_free(app->exec);
            g_free(app->icon);
            g_free(app);
            g_ptr_array_remove_index(g_favorites, i);
            break;
        }
    }
    
    save_favorites();
    update_favorites_bar();
}

static void add_to_favorites(GtkWidget *menuitem, gpointer user_data)
{
    GtkWidget *btn = GTK_WIDGET(user_data);
    const char *name = g_object_get_data(G_OBJECT(btn), "app-name");
    const char *exec = g_object_get_data(G_OBJECT(btn), "app-exec");
    const char *icon = g_object_get_data(G_OBJECT(btn), "app-icon");
    
    if (!g_favorites) {
        g_favorites = g_ptr_array_new();
    }
    
    /* Check if already in favorites */
    for (guint i = 0; i < g_favorites->len; ++i) {
        FavoriteApp *app = g_ptr_array_index(g_favorites, i);
        if (g_strcmp0(app->exec, exec) == 0) {
            return; /* Already exists */
        }
    }
    
    FavoriteApp *fav = g_new0(FavoriteApp, 1);
    fav->name = g_strdup(name);
    fav->exec = g_strdup(exec);
    fav->icon = g_strdup(icon);
    g_ptr_array_add(g_favorites, fav);
    
    save_favorites();
    update_favorites_bar();
    
    /* Flash the newly added favorite button */
    GList *children = gtk_container_get_children(GTK_CONTAINER(g_dock_box));
    if (children) {
        GtkWidget *last = GTK_WIDGET(g_list_last(children)->data);
        flash_widget(last);
    }
    g_list_free(children);
    
    /* Close the launcher window */
    if (g_launcher_window) {
        gtk_widget_destroy(g_launcher_window);
    }
}

/* Right-click menu for app buttons */
static void show_app_context_menu(GtkWidget *btn, GdkEventButton *event)
{
    GtkWidget *menu = gtk_menu_new();
    GtkWidget *add_fav = gtk_menu_item_new_with_label("Add to Favorites");
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), add_fav);
    g_signal_connect(add_fav, "activate", G_CALLBACK(add_to_favorites), btn);
    
    gtk_widget_show_all(menu);
    gtk_menu_popup_at_pointer(GTK_MENU(menu), (GdkEvent*)event);
}

/* Smart search: matches start of words and handles fuzzy matching */
static gboolean smart_match(const char *haystack, const char *needle)
{
    if (!haystack || !needle) return FALSE;
    if (!*needle) return TRUE;
    
    gchar *h = g_utf8_casefold(haystack, -1);
    gchar *n = g_utf8_casefold(needle, -1);
    gboolean result = FALSE;
    
    /* Direct substring match */
    if (strstr(h, n)) {
        result = TRUE;
    } else {
        /* Match start of words */
        gchar **words = g_strsplit(h, " ", -1);
        for (gchar **w = words; !result && *w; ++w) {
            if (g_str_has_prefix(*w, n)) {
                result = TRUE;
            }
        }
        g_strfreev(words);
    }
    
    g_free(h);
    g_free(n);
    return result;
}

/* Search entry handler to filter launcher items */
static void on_search_changed(GtkSearchEntry *entry, gpointer user_data)
{
    const gchar *txt = gtk_entry_get_text(GTK_ENTRY(entry));
    GtkWidget *flow = GTK_WIDGET(user_data);
    GList *children = gtk_container_get_children(GTK_CONTAINER(flow));
    
    for (GList *it = children; it; it = it->next) {
        GtkWidget *child = GTK_WIDGET(it->data);
        const char *name = g_object_get_data(G_OBJECT(child), "app-name");
        if (!name) name = "";
        
        gboolean visible = smart_match(name, txt);
        gtk_widget_set_visible(child, visible);
    }
    
    g_list_free(children);
}

static void show_dock_button_menu(GtkWidget *btn, GdkEventButton *event)
{
    GtkWidget *menu = gtk_menu_new();
    const char *exec = g_object_get_data(G_OBJECT(btn), "app-exec");
    
    if (exec) {
        GtkWidget *remove_item = gtk_menu_item_new_with_label("Remove from Favorites");
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), remove_item);
        g_signal_connect_swapped(remove_item, "activate", G_CALLBACK(remove_from_favorites), (gpointer)exec);
    }
    
    gtk_widget_show_all(menu);
    gtk_menu_popup_at_pointer(GTK_MENU(menu), (GdkEvent*)event);
}

static gboolean on_dock_button_press(GtkWidget *widget, GdkEventButton *event, gpointer data)
{
    if (event->button == 3) { /* right click */
        show_dock_button_menu(widget, event);
        return TRUE;
    } else if (event->button == 1) { /* left click */
        const char *cmd = g_object_get_data(G_OBJECT(widget), "app-exec");
        launch_command(cmd);
        return TRUE;
    }
    return FALSE;
}

static GtkWidget *create_icon_button(const char *icon_name, const char *launch_cmd)
{
    GtkWidget *btn = gtk_button_new();
    GtkWidget *img = gtk_image_new_from_icon_name(icon_name, GTK_ICON_SIZE_DIALOG);
    gtk_container_add(GTK_CONTAINER(btn), img);
    
    /* Store command for launching */
    g_object_set_data_full(G_OBJECT(btn), "app-exec", g_strdup(launch_cmd), g_free);
    
    /* Connect click handler */
    g_signal_connect(btn, "button-press-event", G_CALLBACK(on_dock_button_press), NULL);
    
    gtk_widget_set_tooltip_text(btn, launch_cmd);
    return btn;
}

/* Update the favorites bar with current apps and window states */
static void update_favorites_bar(void)
{
    if (!g_dock_box || !g_favorites) return;
    
    /* Remove existing buttons */
    GList *children = gtk_container_get_children(GTK_CONTAINER(g_dock_box));
    for (GList *it = children; it; it = it->next) {
        gtk_container_remove(GTK_CONTAINER(g_dock_box), GTK_WIDGET(it->data));
    }
    g_list_free(children);
    
    /* Add favorite apps */
    for (guint i = 0; i < g_favorites->len; ++i) {
        FavoriteApp *app = g_ptr_array_index(g_favorites, i);
        GtkWidget *btn = create_icon_button(app->icon ? app->icon : "application-x-executable",
                                          app->exec);
        gtk_box_pack_start(GTK_BOX(g_dock_box), btn, FALSE, FALSE, 0);
    }
    
    gtk_widget_show_all(g_dock_box);
}

/* Window state change handler */
static void on_window_state_changed(WnckScreen *screen, WnckWindow *window, gpointer data)
{
    update_favorites_bar();
}

int main(int argc, char **argv)
{
    gtk_init(&argc, &argv);
    gdk_set_program_class("dock");
    
    /* Initialize window tracking */
    WnckHandle *handle = wnck_handle_new(WNCK_CLIENT_TYPE_APPLICATION);
    g_wnck_screen = wnck_handle_get_default_screen(handle);
    wnck_screen_force_update(g_wnck_screen);
    g_signal_connect(G_OBJECT(g_wnck_screen), "window-opened",
                    G_CALLBACK(on_window_state_changed), NULL);
    g_signal_connect(G_OBJECT(g_wnck_screen), "window-closed",
                    G_CALLBACK(on_window_state_changed), NULL);
    
    /* Load favorites */
    load_favorites();

    /* Create top-level window */
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window), TRUE);
    gtk_window_set_keep_above(GTK_WINDOW(window), TRUE);
    gtk_window_set_type_hint(GTK_WINDOW(window), GDK_WINDOW_TYPE_HINT_DOCK);

    /* Allow transparency */
    GdkScreen *screen = gdk_screen_get_default();
    GdkVisual *visual = gdk_screen_get_rgba_visual(screen);
    if (visual) gtk_widget_set_visual(window, visual);

    /* CSS for rounded semi-transparent background */
    GtkCssProvider *css = gtk_css_provider_new();
    const gchar *style =
        ".dock {"
        "  background-color: rgba(250,250,250,0.18);"
        "  border-radius: 16px;"
        "  padding: 10px;"
        "  margin: 6px;"
        "}"
        ".dock button {"
        "  background: transparent;"
        "  border: none;"
        "  transition: all 200ms ease;"
        "}"
        ".flash {"
        "  background-color: rgba(255,255,255,0.3);"
        "  opacity: 0.8;"
        "}";
    gtk_css_provider_load_from_data(css, style, -1, NULL);
    gtk_style_context_add_provider_for_screen(screen, GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(css);

    /* Container */
    GtkWidget *frame = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_name(frame, "dock");
    gtk_container_add(GTK_CONTAINER(window), frame);

    /* Favorite apps - adapt these commands as desired */
    GtkWidget *btn1 = create_icon_button("firefox", "firefox");
    GtkWidget *btn2 = create_icon_button("org.gnome.Terminal", "gnome-terminal");
    GtkWidget *btn3 = create_icon_button("org.gnome.Nautilus", "nautilus");
    gtk_box_pack_start(GTK_BOX(frame), btn1, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(frame), btn2, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(frame), btn3, FALSE, FALSE, 0);

    /* Spacer */
    GtkWidget *spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_box_pack_start(GTK_BOX(frame), spacer, TRUE, TRUE, 0);

    /* Show apps button */
    GtkWidget *apps_btn = gtk_button_new_with_label("Applications");
    g_signal_connect_swapped(apps_btn, "clicked", G_CALLBACK(show_app_launcher), window);
    gtk_box_pack_end(GTK_BOX(frame), apps_btn, FALSE, FALSE, 0);

    gtk_widget_show_all(window);

    /* Size and position at bottom center */
    gint w = 700, h = 64;
    gtk_window_set_default_size(GTK_WINDOW(window), w, -1);
    GdkRectangle workarea;
    gdk_monitor_get_workarea(gdk_display_get_primary_monitor(gdk_display_get_default()), &workarea);
    gint x = (workarea.width - w) / 2;
    gint y = workarea.height - h - 24;
    gtk_window_move(GTK_WINDOW(window), x, y);

    /* Keep decorations off for nicer look */
    gtk_widget_set_app_paintable(window, TRUE);

    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    /* Create favorites bar */
    g_dock_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    gtk_widget_set_halign(g_dock_box, GTK_ALIGN_CENTER); 
    gtk_box_pack_start(GTK_BOX(frame), g_dock_box, TRUE, TRUE, 0);
    update_favorites_bar();

    gtk_widget_show_all(window);
    gtk_main();

    /* Cleanup */
    if (g_favorites) {
        g_ptr_array_unref(g_favorites); 
    }
    return 0;
}
