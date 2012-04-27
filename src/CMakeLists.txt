find_package(KDE4 REQUIRED)

set(KORUNDUMTEST_KCFG ${CMAKE_CURRENT_SOURCE_DIR}/unidown.kcfg)

find_program(RBUIC4 rbuic4 PATHS ${BIN_INSTALL_DIR})
if(RBUIC4)
	find_program(RBKCONFIG_COMPILER4 rbkconfig_compiler4 PATHS ${BIN_INSTALL_DIR})
	if(RBKCONFIG_COMPILER4)
		add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ui_resultsview_base.rb COMMAND ${RBUIC4} -tr KDE::tr2i18n ${CMAKE_CURRENT_SOURCE_DIR}/resultsview_base.ui -o ${CMAKE_CURRENT_BINARY_DIR}/ui_resultsview_base.rb COMMENT "Generating ui_resultsview_base.rb")
		add_custom_target(resultsview_base ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/ui_resultsview_base.rb)

		add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ui_notificationsview_base.rb COMMAND ${RBUIC4} -tr KDE::tr2i18n ${CMAKE_CURRENT_SOURCE_DIR}/notificationsview_base.ui -o ${CMAKE_CURRENT_BINARY_DIR}/ui_notificationsview_base.rb COMMENT "Generating ui_notificationsview_base.rb")
		add_custom_target(notificationsview_base ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/ui_notificationsview_base.rb)

		install( PROGRAMS unidown.desktop  DESTINATION ${XDG_APPS_INSTALL_DIR} )
		install( FILES unidownui.rc  DESTINATION  ${DATA_INSTALL_DIR}/unidown )

		install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ui_resultsview_base.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ui_notificationsview_base.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/unidown.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/main.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/resultsview.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/resultsmodel.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/notificationsview.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/notificationsmodel.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/kernel.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/unijobss.rb DESTINATION ${DATA_INSTALL_DIR}/unidown)
		install( FILES unidown.kcfg  DESTINATION  ${KCFG_INSTALL_DIR} )
	else(RBKCONFIG_COMPILER4)
		message(STATUS "rbkconfig_compiler4 not found, settings.rb will not created")
	endif(RBKCONFIG_COMPILER4)
else(RBUIC4)
	message(STATUS "rbuic4 not found, unidown will not created")
endif(RBUIC4)


