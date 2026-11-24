#!/usr/bin/env bash
# ============================================================================
# menu.sh - Interactive menu for veycron
# Copyright (c) 2026 veycron
# All rights and ownership belong to https://github.com/Pushpendra-999/veycron.git
# ============================================================================

cmd_menu() {
    ensure_dirs

    while true; do
        clear 2>/dev/null || true
        print_banner
        echo -e "  ${BOLD}Main Menu${NC}"
        echo ""
        echo -e "    ${BOLD}1)${NC}  New Backup Setup"
        echo -e "    ${BOLD}2)${NC}  List Projects"
        echo -e "    ${BOLD}3)${NC}  Run Backup Now"
        echo -e "    ${BOLD}4)${NC}  Project Status"
        echo -e "    ${BOLD}5)${NC}  View Logs"
        echo ""
        echo -e "    ${BOLD}6)${NC}  SMTP Setup"
        echo -e "    ${BOLD}7)${NC}  SMTP Status"
        echo -e "    ${BOLD}8)${NC}  SMTP Test"
        echo ""
        echo -e "    ${BOLD}9)${NC}  Cron Status"
        echo -e "    ${BOLD}10)${NC} Edit Project"
        echo -e "    ${BOLD}11)${NC} Delete Project"
        echo ""
        echo -e "    ${BOLD}12)${NC} System Doctor"
        echo -e "    ${BOLD}13)${NC} Terms & Policy (Copyright)"
        echo ""
        echo -e "    ${BOLD}0)${NC}  Exit"
        echo ""

        echo -en "  ${CYAN}▸${NC} Choose an option: "
        read -r choice

        echo ""

        case "$choice" in
            1)  cmd_new_project ;;
            2)  cmd_list_projects ;;
            3)
                local project=""
                prompt_required "Project name to backup" project
                cmd_run_backup "$project"
                ;;
            4)  cmd_status ;;
            5)
                local proj=""
                prompt_optional "Project name (blank for all)" proj
                cmd_logs "$proj"
                ;;
            6)  cmd_smtp_setup ;;
            7)  cmd_smtp_status ;;
            8)  cmd_smtp_test ;;
            9)  cmd_cron_status ;;
            10)
                local proj=""
                prompt_required "Project name to edit" proj
                cmd_edit_project "$proj"
                ;;
            11)
                local proj=""
                prompt_required "Project name to delete" proj
                cmd_delete_project "$proj"
                ;;
            12) cmd_doctor ;;
            13) cmd_policy ;;
            0|q|quit|exit)
                echo -e "  ${DIM}Goodbye!${NC}"
                return 0
                ;;
            *)
                log_error "Invalid option. Try again."
                ;;
        esac

        echo ""
        echo -en "  ${DIM}Press Enter to return to menu...${NC}"
        read -r
    done
}
